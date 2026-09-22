#!/usr/bin/env python3
"""
generate_mem.py: Mini RV32I Assembler & Memory File Generator
Generates Verilog $readmemh-compatible .mem files for instruction memory.
"""

import sys

def parse_reg(reg_str):
    """Converts 'x0'-'x31' or ABI names ('zero', 'ra', 'sp', etc.) to register index (0-31)."""
    abi_map = {
        "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
        "t0": 5, "t1": 6, "t2": 7, "s0": 8, "fp": 8,
        "s1": 9, "a0": 10, "a1": 11, "a2": 12, "a3": 13,
        "a4": 14, "a5": 15, "a6": 16, "a7": 17, "s2": 18,
        "s3": 19, "s4": 20, "s5": 21, "s6": 22, "s7": 23,
        "s8": 24, "s9": 25, "s10": 26, "s11": 27, "t3": 28,
        "t4": 29, "t5": 30, "t6": 31
    }
    r = reg_str.strip().lower()
    if r in abi_map:
        return abi_map[r]
    if r.startswith("x") and r[1:].isdigit():
        idx = int(r[1:])
        if 0 <= idx <= 31:
            return idx
    raise ValueError(f"Invalid register name: {reg_str}")

def to_twos_complement(val, bits):
    """Converts a signed integer to unsigned bit-field representation."""
    if val < 0:
        val = (1 << bits) + val
    return val & ((1 << bits) - 1)

def assemble_line(asm_line):
    """Assembles a single RV32I instruction string into a 32-bit integer."""
    line = asm_line.split("//")[0].split("#")[0].strip()
    if not line:
        return None

    # Replace commas and parens with whitespace
    tokens = line.replace(",", " ").replace("(", " ").replace(")", " ").split()
    mnemonic = tokens[0].lower()

    if mnemonic == "nop":
        # addi x0, x0, 0
        return 0x00000013

    # I-Type ALU: addi rd, rs1, imm
    elif mnemonic == "addi":
        rd = parse_reg(tokens[1])
        rs1 = parse_reg(tokens[2])
        imm = to_twos_complement(int(tokens[3], 0), 12)
        opcode = 0b0010011
        funct3 = 0b000
        return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

    # R-Type: add / sub rd, rs1, rs2
    elif mnemonic in ("add", "sub", "and", "or", "xor"):
        rd = parse_reg(tokens[1])
        rs1 = parse_reg(tokens[2])
        rs2 = parse_reg(tokens[3])
        opcode = 0b0110011
        funct3_map = {"add": 0, "sub": 0, "xor": 4, "or": 6, "and": 7}
        funct7_map = {"add": 0x00, "sub": 0x20, "xor": 0x00, "or": 0x00, "and": 0x00}
        return (funct7_map[mnemonic] << 25) | (rs2 << 20) | (rs1 << 15) | (funct3_map[mnemonic] << 12) | (rd << 7) | opcode

    # J-Type: jal rd, imm
    elif mnemonic == "jal":
        rd = parse_reg(tokens[1])
        offset = int(tokens[2], 0)
        imm21 = to_twos_complement(offset, 21)
        imm_20    = (imm21 >> 20) & 0x1
        imm_10_1  = (imm21 >> 1)  & 0x3FF
        imm_11    = (imm21 >> 11) & 0x1
        imm_19_12 = (imm21 >> 12) & 0xFF
        imm_field = (imm_20 << 19) | (imm_19_12 << 11) | (imm_11 << 10) | imm_10_1
        opcode = 0b1101111
        return (imm_field << 12) | (rd << 7) | opcode

    # Raw hex word passthrough: e.g. 0x11111113
    elif mnemonic.startswith("0x") or len(mnemonic) == 8:
        return int(mnemonic, 16)

    else:
        raise NotImplementedError(f"Mnemonic '{mnemonic}' not yet supported in mini-assembler.")

def generate_mem_file(assembly_list, output_filename="program.mem", mem_depth=64):
    """Encodes instructions and writes out a padded $readmemh memory file."""
    instructions = []
    for line in assembly_list:
        clean = line.strip()
        if not clean or clean.startswith("//") or clean.startswith("#"):
            continue
        word = assemble_line(clean)
        if word is not None:
            instructions.append((word, clean))

    if len(instructions) > mem_depth:
        raise ValueError(f"Program size ({len(instructions)} words) exceeds MEM_DEPTH ({mem_depth} words)!")

    with open(output_filename, "w") as f:
        f.write(f"// Verilog $readmemh Memory File: {output_filename}\n")
        f.write(f"// Format: 32-bit Hexadecimal Words | Depth: {mem_depth} words\n\n")

        for idx in range(mem_depth):
            byte_addr = idx * 4
            if idx < len(instructions):
                code, asm = instructions[idx]
                f.write(f"{code:08X} // [0x{byte_addr:04X} | Word {idx:2d}]: {asm}\n")
            else:
                # Pad remainder of memory with RV32I NOPs (0x00000013)
                f.write(f"00000013 // [0x{byte_addr:04X} | Word {idx:2d}]: nop (padding)\n")

    print(f"[SUCCESS] Generated '{output_filename}' ({len(instructions)} instructions, padded to {mem_depth} words).")

# -----------------------------------------------------------------
# Day 80 Verification Test Program
# -----------------------------------------------------------------
if __name__ == "__main__":
    # Test assembly program matching Day 80 self-checking testbench
    test_program = [
        "addi x1, x0, 5",      # PC = 0x00 -> 0x00500093
        "addi x2, x0, 10",     # PC = 0x04 -> 0x00A00113
        "add  x3, x1, x2",     # PC = 0x08 -> 0x002081B3
        "sub  x4, x2, x1",     # PC = 0x0C -> 0x40110233
        "jal  x0, 0",          # PC = 0x10 -> 0x0000006F (Infinite loop)
        "nop",                 # PC = 0x14 -> 0x00000013
        "nop",                 # PC = 0x18 -> 0x00000013
        "nop",                 # PC = 0x1C -> 0x00000013
        "0x11111113",          # PC = 0x20 -> Branch target instruction
    ]

    target_file = sys.argv[1] if len(sys.argv) > 1 else "program.mem"
    generate_mem_file(test_program, output_filename=target_file, mem_depth=64)