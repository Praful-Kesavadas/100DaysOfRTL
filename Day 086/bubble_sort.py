from generate_mem import generate

# 8-element unsorted array (word-aligned, base address 0x0 in dmem)
ARRAY = [42, 17, 8, 99, 23, 4, 56, 71, 4, 6]
N = len(ARRAY)

program = []

# ---- load the unsorted array into data memory ----
program.append("addi x1, x0, 0")          # x1 = base address of array
for i, val in enumerate(ARRAY):
    program.append(f"addi x10, x0, {val}")
    program.append(f"sw   x10, {i*4}(x1)")

# ---- bubble sort (N-1 full passes, no early-exit optimization) ----
program += [
    f"addi x2, x0, {N-1}",       # x2 = outer passes remaining
    f"addi x4, x0, {(N-1)*4}",   # x4 = inner-loop bound (byte offset of last comparable pair)

    "OUTER: beq x2, x0, DONE",   # all passes done -> exit
    "addi x3, x0, 0",            # x3 = j (byte offset), reset each pass

    "INNER: bge x3, x4, INNER_DONE",  # j >= bound -> end of this pass
    "add  x5, x1, x3",            # x5 = &a[j]
    "lw   x6, 0(x5)",             # x6 = a[j]
    "addi x7, x5, 4",             # x7 = &a[j+1]
    "lw   x8, 0(x7)",             # x8 = a[j+1]   (load-use hazard: x8 consumed next line)
    "blt  x8, x6, DO_SWAP",       # a[j+1] < a[j] -> out of order, swap
    "jal  x0, NO_SWAP",

    "DO_SWAP: sw x8, 0(x5)",      # a[j]   = a[j+1]
    "sw   x6, 0(x7)",             # a[j+1] = a[j]

    "NO_SWAP: addi x3, x3, 4",    # j += 4
    "jal  x0, INNER",

    "INNER_DONE: addi x2, x2, -1",  # passes -= 1
    "jal  x0, OUTER",

    "DONE: jal x0, DONE",          # halt self-loop
]

if __name__ == "__main__":
    print(f"Unsorted array: {ARRAY}")
    print(f"Expected sorted: {sorted(ARRAY)}")
    trace, mem_events = generate(program, mem_filename="program.mem",
                                  expected_filename="expected_trace.mem",
                                  count_filename="expected_count.vh",
                                  mem_depth=256, dmem_depth_bytes=1024)

    # --- keep tb.v in sync with N automatically (no manual edits needed) ---

    # 1) The original (unsorted) values, so tb.v can print them without
    #    re-deriving them from anywhere -- dmem itself gets overwritten by
    #    the sort, so this is the only place they still exist after the run.
    with open("unsorted_array.mem", "w") as f:
        f.write(f"// Original unsorted values ({N} words), for tb.v display only\n")
        for v in ARRAY:
            f.write(f"{v & 0xFFFFFFFF:08X}\n")

    # 2) ARRAY_WORDS (=N) and a timeout sized to this run, both derived from
    #    the actual assembled program rather than hand-copied into tb.v.
    #    Bubble sort's dynamic instruction count is ~O(N^2), so a fixed
    #    TIMEOUT_CYCLES that was fine for N=8 will falsely time out at
    #    larger N -- size it off the real trace length with a 3x safety
    #    margin (covers stalls/squashes) instead of a guessed constant.
    timeout_cycles = max(5000, len(trace) * 3)
    with open("array_params.vh", "w") as f:
        f.write(f"`define ARRAY_WORDS {N}\n")
        f.write(f"`define TIMEOUT_CYCLES {timeout_cycles}\n")

    print(f"[SUCCESS] array_params.vh: ARRAY_WORDS={N}, TIMEOUT_CYCLES={timeout_cycles}")
    print(f"[SUCCESS] unsorted_array.mem: {N} original values saved for tb.v display")