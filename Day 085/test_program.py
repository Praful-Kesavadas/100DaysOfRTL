from generate_mem import generate

program = [
    # ================= Section 1: R-type ALU coverage =================
    "addi x1, x0, 7",
    "addi x2, x0, 3",
    "add  x3, x1, x2",      # 10
    "sub  x4, x1, x2",      # 4
    "sll  x5, x1, x2",      # 7<<3 = 56
    "slt  x6, x2, x1",      # 3<7 -> 1
    "sltu x7, x1, x2",      # 7<3(u) -> 0
    "xor  x8, x1, x2",
    "srl  x9, x1, x2",
    "sra  x10, x1, x2",
    "or   x11, x1, x2",
    "and  x12, x1, x2",

    # ================= Section 2: I-type ALU + immediate edges =================
    "addi x13, x0, 2047",     # max positive 12-bit imm
    "addi x14, x0, -2048",    # max negative 12-bit imm
    "slti x15, x13, 2048",    # 2047 < 2048 -> 1
    "sltiu x16, x0, 1",       # 0 <u 1 -> 1
    "xori x17, x13, -1",
    "ori  x18, x0, 255",
    "andi x19, x13, 15",
    "slli x20, x1, 4",
    "srli x21, x1, 1",
    "srai x22, x14, 1",

    # ================= Section 3: Forwarding =================
    "addi x23, x0, 1",
    "add  x24, x23, x23",     # EX/MEM forward (producer immediately before)
    "addi x25, x0, 5",
    "nop",
    "add  x26, x25, x25",     # MEM/WB forward (one instruction gap)
    "addi x27, x0, 2",
    "add  x28, x27, x27",     # producer for next line's EX/MEM forward
    "add  x29, x28, x27",     # double hazard: x28 EX/MEM-forward, x27 plain regfile read

    # ================= Section 4: Load-use hazard =================
    "addi x31, x0, 0x100",
    "sw   x24, 0(x31)",
    "lw   x5, 0(x31)",
    "add  x6, x5, x5",        # immediately dependent on load -> load-use stall expected

    # ================= Section 5: Load/store width + byte-offset coverage =================
    "addi x31, x0, 0x200",
    "addi x7, x0, -1",
    "sb   x7, 0(x31)",
    "lb   x8, 0(x31)",        # signed byte load of 0xFF -> -1
    "lbu  x9, 0(x31)",        # unsigned byte load of 0xFF -> 0x000000FF

    "addi x10, x0, 0x1234",
    "sh   x10, 4(x31)",
    "lh   x11, 4(x31)",       # 0x1234 positive, sign bit clear
    "lhu  x12, 4(x31)",

    "addi x13, x0, -100",
    "sw   x13, 8(x31)",
    "lw   x14, 8(x31)",

    "addi x16, x0, -1",
    "sh   x16, 12(x31)",      # store 0xFFFF
    "lh   x17, 12(x31)",      # sign-extended -> -1
    "lhu  x18, 12(x31)",      # zero-extended -> 0x0000FFFF

    # byte offsets 1, 2, 3 within a word
    "addi x19, x0, 0x11",
    "sb   x19, 17(x31)",      # (0x200+17)&3 = 1
    "lb   x20, 17(x31)",
    "addi x21, x0, 0x22",
    "sb   x21, 18(x31)",      # &3 = 2
    "lb   x22, 18(x31)",
    "addi x23, x0, 0x33",
    "sb   x23, 19(x31)",      # &3 = 3
    "lb   x24, 19(x31)",

    # ================= Section 6: Misalignment traps =================
    "addi x25, x0, 0x55",
    "sh   x25, 1(x31)",       # misaligned half store -> trap_store_misaligned, memory unchanged
    "lh   x26, 1(x31)",       # misaligned half load -> trap_load_misaligned, no reg write

    "addi x27, x0, 0x66",
    "sw   x27, 2(x31)",       # misaligned word store
    "lw   x28, 2(x31)",       # misaligned word load

    # misaligned load immediately followed by a dependent consumer: must stall (load-use
    # hazard doesn't know about eventual misalignment) yet must NOT forward garbage --
    # x19 must be observed unchanged by the consumer, since the load never actually writes.
    "addi x19, x0, 42",
    "lh   x19, 1(x31)",       # misaligned; x19 should remain 42 architecturally
    "add  x20, x19, x0",      # must read the OLD x19 == 42, not corrupted

    # ================= Section 7: Branches =================
    "addi x1, x0, 5",
    "addi x2, x0, 5",
    "addi x3, x0, 9",

    "beq  x1, x2, BEQ_T",     # taken
    "addi x4, x0, 0xDEA",     # must be squashed
    "BEQ_T: addi x5, x0, 1",

    "bne  x1, x2, BNE_NT",    # NOT taken (x1==x2)
    "addi x6, x0, 2",         # executes (fallthrough)
    "BNE_NT: addi x7, x0, 3",

    "blt  x2, x3, BLT_T",     # 5<9 -> taken
    "addi x8, x0, 0xDEA",
    "BLT_T: addi x9, x0, 4",

    "bge  x3, x2, BGE_T",     # 9>=5 -> taken
    "addi x10, x0, 0xDEA",
    "BGE_T: addi x11, x0, 5",

    "bltu x1, x3, BLTU_T",    # 5 <u 9 -> taken
    "addi x12, x0, 0xDEA",
    "BLTU_T: addi x13, x0, 6",

    "bgeu x3, x1, BGEU_T",    # 9 >=u 5 -> taken
    "addi x14, x0, 0xDEA",
    "BGEU_T: addi x15, x0, 7",

    # back-to-back taken branches (double control-hazard flush)
    "beq  x1, x2, BB1",       # taken -> lands exactly on the next branch
    "BB1: beq x0, x0, BB2",   # unconditionally taken
    "addi x16, x0, 0xDEA",    # must be squashed
    "BB2: addi x17, x0, 8",

    # branch operand forwarded from the immediately preceding instruction (EX/MEM forward
    # feeding straight into the branch comparator)
    "addi x18, x0, 10",
    "add  x19, x18, x18",     # x19 = 20, producer right before the branch
    "beq  x19, x19, FWD_BR1",
    "addi x20, x0, 0xDEA",
    "FWD_BR1: addi x21, x0, 9",

    # branch with two DIFFERENT forwarded operands: one EX/MEM-stage, one MEM/WB-stage
    "addi x22, x0, 15",
    "addi x23, x0, 15",
    "add  x24, x22, x0",      # x24=15, will be MEM/WB-stage by the time the branch executes
    "add  x25, x23, x0",      # x25=15, will be EX/MEM-stage by the time the branch executes
    "beq  x24, x25, FWD_BR2",
    "addi x26, x0, 0xDEA",
    "FWD_BR2: addi x27, x0, 10",

    # ================= Section 8: JAL / JALR =================
    "jal  x28, JAL_T",        # x28 = return addr (pc+4)
    "addi x29, x0, 0xDEA",    # squashed
    "JAL_T: addi x30, x0, 11",

    "jalr x6, x0, JALR_T",    # x0-relative absolute jump idiom; x6 = return addr
    "addi x7, x0, 0xDEA",     # squashed
    "JALR_T: addi x8, x0, 12",

    # ================= Section 9: LUI / AUIPC =================
    "lui   x9, 0x87654",      # x9 = 0x87654000
    "auipc x10, 1",           # x10 = pc_of_this_instr + 0x1000

    # ================= Section 10: x0 semantics =================
    "addi x0, x0, 999",       # attempted write to x0 -> must be dropped
    "add  x0, x1, x2",        # attempted write to x0 -> must be dropped
    "addi x31, x0, 0",        # read x0 as a source -> must read back 0

    # ================= Section 11: Halt =================
    "HALT: jal x0, HALT",     # self-loop: golden sim + hardware both spin here forever
]

if __name__ == "__main__":
    generate(program, mem_filename="program.mem",
              expected_filename="expected_trace.mem",
              count_filename="expected_count.vh",
              mem_depth=256, dmem_depth_bytes=1024)