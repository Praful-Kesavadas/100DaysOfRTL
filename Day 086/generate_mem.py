#!/usr/bin/env python3
"""
generate_mem.py: RV32I Assembler, Memory File Generator, and Golden Reference Model.

Extends the original mini-assembler (addi/R-type ALU/jal/nop) with the rest of the
base integer ISA the riscv_core datapath actually decodes (branches, loads, stores,
shifts, slt/sltu, jalr, lui, auipc), adds two-pass label resolution so branch/jump
offsets don't have to be hand-computed, and adds a small architectural (golden)
simulator that walks the assembled program exactly the way the 5-stage core will
(respecting taken branches) and emits the expected dynamic retirement trace for a
self-checking testbench to compare against, cycle by cycle.
"""

import sys
import re

# -----------------------------------------------------------------
# Register name resolution
# -----------------------------------------------------------------
ABI_MAP = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
    "t0": 5, "t1": 6, "t2": 7, "s0": 8, "fp": 8,
    "s1": 9, "a0": 10, "a1": 11, "a2": 12, "a3": 13,
    "a4": 14, "a5": 15, "a6": 16, "a7": 17, "s2": 18,
    "s3": 19, "s4": 20, "s5": 21, "s6": 22, "s7": 23,
    "s8": 24, "s9": 25, "s10": 26, "s11": 27, "t3": 28,
    "t4": 29, "t5": 30, "t6": 31
}

def parse_reg(reg_str):
    r = reg_str.strip().lower()
    if r in ABI_MAP:
        return ABI_MAP[r]
    if r.startswith("x") and r[1:].isdigit():
        idx = int(r[1:])
        if 0 <= idx <= 31:
            return idx
    raise ValueError(f"Invalid register name: {reg_str}")

def to_twos_complement(val, bits):
    if val < 0:
        val = (1 << bits) + val
    return val & ((1 << bits) - 1)

def sign_extend(val, bits):
    """Interpret an unsigned `bits`-wide field as a signed Python int."""
    val &= (1 << bits) - 1
    if val & (1 << (bits - 1)):
        val -= (1 << bits)
    return val

def u32(val):
    return val & 0xFFFFFFFF

# -----------------------------------------------------------------
# Instruction-format encoders
# -----------------------------------------------------------------
def enc_r(opcode, rd, funct3, rs1, rs2, funct7):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def enc_i(opcode, rd, funct3, rs1, imm12):
    imm12 = to_twos_complement(imm12, 12)
    return (imm12 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def enc_i_shift(opcode, rd, funct3, rs1, shamt5, funct7):
    return (funct7 << 25) | ((shamt5 & 0x1F) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def enc_s(opcode, funct3, rs1, rs2, imm12):
    imm12 = to_twos_complement(imm12, 12)
    imm_11_5 = (imm12 >> 5) & 0x7F
    imm_4_0 = imm12 & 0x1F
    return (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_0 << 7) | opcode

def enc_b(opcode, funct3, rs1, rs2, imm13):
    imm13 = to_twos_complement(imm13, 13)
    imm_12 = (imm13 >> 12) & 0x1
    imm_10_5 = (imm13 >> 5) & 0x3F
    imm_4_1 = (imm13 >> 1) & 0xF
    imm_11 = (imm13 >> 11) & 0x1
    return (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | \
           (imm_4_1 << 8) | (imm_11 << 7) | opcode

def enc_u(opcode, rd, imm20):
    imm20 = to_twos_complement(imm20, 20)
    return (imm20 << 12) | (rd << 7) | opcode

def enc_j(opcode, rd, imm21):
    # J-type field order per the RV32I spec (and this core's imm_gen.v):
    # instr[31]=imm[20], instr[30:21]=imm[10:1], instr[20]=imm[11], instr[19:12]=imm[19:12].
    # NOTE: the original script's encoder had these swapped (imm_19_12 and imm_10_1
    # transposed), which only ever escaped detection because its only test case was
    # `jal x0, 0` -- an all-zero offset that's invariant to field ordering.
    imm21 = to_twos_complement(imm21, 21)
    imm_20 = (imm21 >> 20) & 0x1
    imm_10_1 = (imm21 >> 1) & 0x3FF
    imm_11 = (imm21 >> 11) & 0x1
    imm_19_12 = (imm21 >> 12) & 0xFF
    imm_field = (imm_20 << 19) | (imm_10_1 << 9) | (imm_11 << 8) | imm_19_12
    return (imm_field << 12) | (rd << 7) | opcode

OPC_OP      = 0b0110011
OPC_OP_IMM  = 0b0010011
OPC_LOAD    = 0b0000011
OPC_STORE   = 0b0100011
OPC_BRANCH  = 0b1100011
OPC_LUI     = 0b0110111
OPC_AUIPC   = 0b0010111
OPC_JAL     = 0b1101111
OPC_JALR    = 0b1100111

R_TYPE = {
    "add":  (0b000, 0b0000000), "sub":  (0b000, 0b0100000),
    "sll":  (0b001, 0b0000000), "slt":  (0b010, 0b0000000),
    "sltu": (0b011, 0b0000000), "xor":  (0b100, 0b0000000),
    "srl":  (0b101, 0b0000000), "sra":  (0b101, 0b0100000),
    "or":   (0b110, 0b0000000), "and":  (0b111, 0b0000000),
}
I_ALU = {
    "addi":  0b000, "slti": 0b010, "sltiu": 0b011,
    "xori":  0b100, "ori":  0b110, "andi":  0b111,
}
I_SHIFT = {
    "slli": (0b001, 0b0000000), "srli": (0b101, 0b0000000), "srai": (0b101, 0b0100000),
}
LOADS = {"lb": 0b000, "lh": 0b001, "lw": 0b010, "lbu": 0b100, "lhu": 0b101}
STORES = {"sb": 0b000, "sh": 0b001, "sw": 0b010}
BRANCHES = {"beq": 0b000, "bne": 0b001, "blt": 0b100, "bge": 0b101, "bltu": 0b110, "bgeu": 0b111}

# -----------------------------------------------------------------
# Pass 1: strip comments/labels, assign addresses
# -----------------------------------------------------------------
LABEL_DEF_RE = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$')

def strip_comment(line):
    return line.split("//")[0].split("#")[0].rstrip()

def first_pass(assembly_list):
    labels = {}
    instr_lines = []
    addr = 0
    for raw in assembly_list:
        line = strip_comment(raw).strip()
        if not line:
            continue
        m = LABEL_DEF_RE.match(line)
        if m:
            labels[m.group(1)] = addr
            rest = m.group(2).strip()
            if not rest:
                continue
            line = rest
        instr_lines.append([addr, line])
        addr += 4
    return instr_lines, labels

def resolve_operand(tok, labels, cur_addr, pc_relative):
    tok = tok.strip()
    if tok in labels:
        target = labels[tok]
        return (target - cur_addr) if pc_relative else target
    return int(tok, 0)

# -----------------------------------------------------------------
# Pass 2: assemble
# -----------------------------------------------------------------
def assemble_line(line, labels, cur_addr):
    tokens = line.replace(",", " ").replace("(", " ").replace(")", " ").split()
    mnemonic = tokens[0].lower()

    if mnemonic == "nop":
        return 0x00000013

    if mnemonic in R_TYPE:
        rd, rs1, rs2 = parse_reg(tokens[1]), parse_reg(tokens[2]), parse_reg(tokens[3])
        f3, f7 = R_TYPE[mnemonic]
        return enc_r(OPC_OP, rd, f3, rs1, rs2, f7)

    if mnemonic in I_ALU:
        rd, rs1 = parse_reg(tokens[1]), parse_reg(tokens[2])
        imm = resolve_operand(tokens[3], labels, cur_addr, pc_relative=False)
        return enc_i(OPC_OP_IMM, rd, I_ALU[mnemonic], rs1, imm)

    if mnemonic in I_SHIFT:
        rd, rs1 = parse_reg(tokens[1]), parse_reg(tokens[2])
        shamt = int(tokens[3], 0)
        f3, f7 = I_SHIFT[mnemonic]
        return enc_i_shift(OPC_OP_IMM, rd, f3, rs1, shamt, f7)

    if mnemonic in LOADS:
        rd = parse_reg(tokens[1])
        imm = int(tokens[2], 0)
        rs1 = parse_reg(tokens[3])
        return enc_i(OPC_LOAD, rd, LOADS[mnemonic], rs1, imm)

    if mnemonic in STORES:
        rs2 = parse_reg(tokens[1])
        imm = int(tokens[2], 0)
        rs1 = parse_reg(tokens[3])
        return enc_s(OPC_STORE, STORES[mnemonic], rs1, rs2, imm)

    if mnemonic in BRANCHES:
        rs1, rs2 = parse_reg(tokens[1]), parse_reg(tokens[2])
        offset = resolve_operand(tokens[3], labels, cur_addr, pc_relative=True)
        return enc_b(OPC_BRANCH, BRANCHES[mnemonic], rs1, rs2, offset)

    if mnemonic == "jal":
        rd = parse_reg(tokens[1])
        offset = resolve_operand(tokens[2], labels, cur_addr, pc_relative=True)
        return enc_j(OPC_JAL, rd, offset)

    if mnemonic == "jalr":
        rd, rs1 = parse_reg(tokens[1]), parse_reg(tokens[2])
        # imm may be a plain literal or a label (resolved as an ABSOLUTE address,
        # not pc-relative -- pair with `rs1 = x0` for a clean "jump to label" idiom)
        imm = resolve_operand(tokens[3], labels, cur_addr, pc_relative=False)
        return enc_i(OPC_JALR, rd, 0b000, rs1, imm)

    if mnemonic == "lui":
        rd = parse_reg(tokens[1])
        imm20 = int(tokens[2], 0)
        return enc_u(OPC_LUI, rd, imm20)

    if mnemonic == "auipc":
        rd = parse_reg(tokens[1])
        imm20 = int(tokens[2], 0)
        return enc_u(OPC_AUIPC, rd, imm20)

    if mnemonic.startswith("0x") or len(mnemonic) == 8:
        return int(mnemonic, 16)

    raise NotImplementedError(f"Mnemonic '{mnemonic}' not supported: '{line}'")


# -----------------------------------------------------------------
# Golden architectural simulator
# -----------------------------------------------------------------
class GoldenSim:
    def __init__(self, word_mem, dmem_bytes):
        self.word_mem = word_mem
        self.regs = [0] * 32
        self.dmem = bytearray(dmem_bytes)
        self.pc = 0
        self.trace = []
        self.mem_events = []

    def rd_reg(self, i):
        return 0 if i == 0 else self.regs[i]

    def load_word(self, byte_addr):
        word_addr = byte_addr & ~0x3
        idx = word_addr % len(self.dmem)
        return int.from_bytes(self.dmem[idx:idx+4], "little")

    def store_word(self, byte_addr, value, wstrb):
        word_addr = byte_addr & ~0x3
        idx = word_addr % len(self.dmem)
        cur = bytearray(self.dmem[idx:idx+4])
        val_bytes = value.to_bytes(4, "little")
        for b in range(4):
            if wstrb & (1 << b):
                cur[b] = val_bytes[b]
        self.dmem[idx:idx+4] = cur

    def run(self, max_steps=100000):
        for _ in range(max_steps):
            instr = self.word_mem.get(self.pc, 0x00000013)
            opcode = instr & 0x7F
            rd = (instr >> 7) & 0x1F
            funct3 = (instr >> 12) & 0x7
            rs1 = (instr >> 15) & 0x1F
            rs2 = (instr >> 20) & 0x1F
            funct7 = (instr >> 25) & 0x7F

            pc = self.pc
            pc_plus_4 = u32(pc + 4)
            next_pc = pc_plus_4
            writes_reg = False
            wdata = 0
            halt_self_loop = False
            mem_event = None

            if opcode == OPC_OP:
                a, b = self.rd_reg(rs1), self.rd_reg(rs2)
                sa, sb = sign_extend(a, 32), sign_extend(b, 32)
                shamt = b & 0x1F
                if funct3 == 0b000:
                    wdata = u32(a - b) if funct7 & 0x20 else u32(a + b)
                elif funct3 == 0b001:
                    wdata = u32(a << shamt)
                elif funct3 == 0b010:
                    wdata = 1 if sa < sb else 0
                elif funct3 == 0b011:
                    wdata = 1 if a < b else 0
                elif funct3 == 0b100:
                    wdata = a ^ b
                elif funct3 == 0b101:
                    wdata = u32(sa >> shamt) if funct7 & 0x20 else (a >> shamt)
                elif funct3 == 0b110:
                    wdata = a | b
                elif funct3 == 0b111:
                    wdata = a & b
                writes_reg = True

            elif opcode == OPC_OP_IMM:
                imm = sign_extend((instr >> 20) & 0xFFF, 12)
                a = self.rd_reg(rs1)
                sa = sign_extend(a, 32)
                shamt = imm & 0x1F
                if funct3 == 0b000:
                    wdata = u32(a + imm)
                elif funct3 == 0b010:
                    wdata = 1 if sa < imm else 0
                elif funct3 == 0b011:
                    wdata = 1 if a < u32(imm) else 0
                elif funct3 == 0b100:
                    wdata = u32(a ^ imm)
                elif funct3 == 0b110:
                    wdata = u32(a | imm)
                elif funct3 == 0b111:
                    wdata = u32(a & imm)
                elif funct3 == 0b001:
                    wdata = u32(a << shamt)
                elif funct3 == 0b101:
                    wdata = u32(sa >> shamt) if funct7 & 0x20 else (a >> shamt)
                writes_reg = True

            elif opcode == OPC_LOAD:
                imm = sign_extend((instr >> 20) & 0xFFF, 12)
                addr = u32(self.rd_reg(rs1) + imm)
                byte_off = addr & 0x3
                misaligned = ((funct3 & 0x3) == 0b01 and (byte_off & 1)) or \
                             ((funct3 & 0x3) == 0b10 and byte_off != 0)
                mem_event = {"kind": "load", "misaligned": misaligned}
                if not misaligned:
                    word = self.load_word(addr)
                    if funct3 == 0b000:
                        b = (word >> (byte_off * 8)) & 0xFF
                        wdata = u32(sign_extend(b, 8))
                    elif funct3 == 0b001:
                        h = (word >> (16 if byte_off & 0x2 else 0)) & 0xFFFF
                        wdata = u32(sign_extend(h, 16))
                    elif funct3 == 0b010:
                        wdata = word
                    elif funct3 == 0b100:
                        wdata = (word >> (byte_off * 8)) & 0xFF
                    elif funct3 == 0b101:
                        wdata = (word >> (16 if byte_off & 0x2 else 0)) & 0xFFFF
                    writes_reg = True

            elif opcode == OPC_STORE:
                imm_11_5 = (instr >> 25) & 0x7F
                imm_4_0 = (instr >> 7) & 0x1F
                imm = sign_extend((imm_11_5 << 5) | imm_4_0, 12)
                addr = u32(self.rd_reg(rs1) + imm)
                byte_off = addr & 0x3
                misaligned = ((funct3 & 0x3) == 0b01 and (byte_off & 1)) or \
                             ((funct3 & 0x3) == 0b10 and byte_off != 0)
                mem_event = {"kind": "store", "misaligned": misaligned}
                if not misaligned:
                    val = self.rd_reg(rs2)
                    # Mirror riscv_mem_stage.v exactly: dmem_wdata replicates the LOW byte/
                    # halfword of the register across all four lanes, and wstrb alone selects
                    # which lane(s) actually get written -- NOT the position-matched byte of the
                    # full 32-bit register value (that was a bug: fixed here).
                    if funct3 == 0b000:
                        replicated = u32(val & 0xFF) * 0x01010101
                        self.store_word(addr, replicated, 1 << byte_off)
                    elif funct3 == 0b001:
                        half = val & 0xFFFF
                        replicated = (half << 16) | half
                        self.store_word(addr, replicated, 0b1100 if byte_off & 0x2 else 0b0011)
                    elif funct3 == 0b010:
                        self.store_word(addr, val, 0b1111)

            elif opcode == OPC_BRANCH:
                imm_12 = (instr >> 31) & 0x1
                imm_11 = (instr >> 7) & 0x1
                imm_10_5 = (instr >> 25) & 0x3F
                imm_4_1 = (instr >> 8) & 0xF
                imm = sign_extend((imm_12 << 12) | (imm_11 << 11) | (imm_10_5 << 5) | (imm_4_1 << 1), 13)
                a, b = self.rd_reg(rs1), self.rd_reg(rs2)
                sa, sb = sign_extend(a, 32), sign_extend(b, 32)
                taken = {
                    0b000: a == b, 0b001: a != b,
                    0b100: sa < sb, 0b101: sa >= sb,
                    0b110: a < b, 0b111: a >= b,
                }.get(funct3, False)
                if taken:
                    next_pc = u32(pc + imm)

            elif opcode == OPC_LUI:
                imm20 = (instr >> 12) & 0xFFFFF
                wdata = u32(imm20 << 12)
                writes_reg = True

            elif opcode == OPC_AUIPC:
                imm20 = (instr >> 12) & 0xFFFFF
                wdata = u32(pc + (imm20 << 12))
                writes_reg = True

            elif opcode == OPC_JAL:
                imm_20 = (instr >> 31) & 0x1
                imm_19_12 = (instr >> 12) & 0xFF
                imm_11 = (instr >> 20) & 0x1
                imm_10_1 = (instr >> 21) & 0x3FF
                imm = sign_extend((imm_20 << 20) | (imm_19_12 << 12) | (imm_11 << 11) | (imm_10_1 << 1), 21)
                target = u32(pc + imm)
                if target == pc:
                    halt_self_loop = True
                wdata = pc_plus_4
                writes_reg = True
                next_pc = target

            elif opcode == OPC_JALR:
                imm = sign_extend((instr >> 20) & 0xFFF, 12)
                target = u32((self.rd_reg(rs1) + imm) & ~0x1)
                wdata = pc_plus_4
                writes_reg = True
                next_pc = target

            else:
                if instr != 0:
                    raise ValueError(f"Unrecognized opcode 0b{opcode:07b} at PC=0x{pc:04x} (word=0x{instr:08x})")

            if instr != 0:
                reg_write_final = writes_reg and (rd != 0) and not (mem_event and mem_event["misaligned"])
                if reg_write_final:
                    self.regs[rd] = u32(wdata)
                self.trace.append({
                    "pc": pc, "rd": rd if reg_write_final else 0,
                    "data": wdata if reg_write_final else 0,
                    "writes": reg_write_final,
                })
                if mem_event:
                    self.mem_events.append(mem_event)

            if halt_self_loop:
                break
            self.pc = next_pc
        return self.trace, self.mem_events


# -----------------------------------------------------------------
# Top-level generation
# -----------------------------------------------------------------
def generate(assembly_list, mem_filename="program.mem", expected_filename="expected_trace.mem",
             count_filename="expected_count.vh", mem_depth=256, dmem_depth_bytes=1024):
    instr_lines, labels = first_pass(assembly_list)

    encoded = {}
    for addr, text in instr_lines:
        word = assemble_line(text, labels, addr)
        encoded[addr] = u32(word)

    n_instr = len(instr_lines)
    if n_instr > mem_depth:
        raise ValueError(f"Program size ({n_instr} words) exceeds MEM_DEPTH ({mem_depth})")

    with open(mem_filename, "w") as f:
        f.write(f"// Verilog $readmemh Memory File: {mem_filename}\n")
        f.write(f"// Format: 32-bit Hexadecimal Words | Depth: {mem_depth} words\n\n")
        lookup = dict(instr_lines)
        for idx in range(mem_depth):
            byte_addr = idx * 4
            if byte_addr in encoded:
                f.write(f"{encoded[byte_addr]:08X} // [0x{byte_addr:04X} | Word {idx:3d}]: {lookup[byte_addr]}\n")
            else:
                f.write(f"00000013 // [0x{byte_addr:04X} | Word {idx:3d}]: nop (padding)\n")

    sim = GoldenSim(encoded, dmem_depth_bytes)
    trace, mem_events = sim.run()

    with open(expected_filename, "w") as f:
        f.write(f"// Expected dynamic retirement trace ({len(trace)} entries)\n")
        f.write(f"// Format: [has_write(1) | rd(5) | pc(32) | data(32)] packed as 70-bit hex\n")
        for e in trace:
            packed = (int(e["writes"]) << 69) | (e["rd"] << 64) | (e["pc"] << 32) | e["data"]
            f.write(f"{packed:018X} // PC=0x{e['pc']:04X} rd=x{e['rd']} data=0x{e['data']:08X} write={int(e['writes'])}\n")

    with open(count_filename, "w") as f:
        f.write(f"`define EXPECTED_COUNT {len(trace)}\n")
        f.write(f"`define EXPECTED_MEM_EVENTS {len(mem_events)}\n")

    mem_events_filename = "expected_mem_events.mem"
    with open(mem_events_filename, "w") as f:
        f.write(f"// Expected dynamic load/store MEM-stage events ({len(mem_events)} entries)\n")
        f.write(f"// Format: 1 hex digit = [kind(1: 0=load,1=store)][misaligned(1)]\n")
        for m in mem_events:
            kind_bit = 1 if m["kind"] == "store" else 0
            packed = (kind_bit << 1) | int(m["misaligned"])
            f.write(f"{packed:X} // {m['kind']} misaligned={int(m['misaligned'])}\n")

    n_load_trap = sum(1 for m in mem_events if m["kind"] == "load" and m["misaligned"])
    n_store_trap = sum(1 for m in mem_events if m["kind"] == "store" and m["misaligned"])
    print(f"[SUCCESS] {mem_filename}: {n_instr} instructions (padded to {mem_depth}).")
    print(f"[SUCCESS] {expected_filename}: {len(trace)} dynamic retirements "
          f"({n_load_trap} misaligned loads, {n_store_trap} misaligned stores expected).")
    print(f"[SUCCESS] {mem_events_filename}: {len(mem_events)} MEM-stage load/store events")
    print(f"[SUCCESS] {count_filename}: EXPECTED_COUNT={len(trace)}, EXPECTED_MEM_EVENTS={len(mem_events)}")
    return trace, mem_events


if __name__ == "__main__":
    test_program = [
        "addi x1, x0, 5",
        "addi x2, x0, 10",
        "add  x3, x1, x2",
        "sub  x4, x2, x1",
        "jal  x0, 0",
        "nop",
        "nop",
        "nop",
        "0x11111113",
    ]
    target_file = sys.argv[1] if len(sys.argv) > 1 else "program.mem"
    generate(test_program, mem_filename=target_file)