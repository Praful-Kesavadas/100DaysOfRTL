`timescale 1ns / 1ps
`include "expected_count.vh"
`include "array_params.vh"     // ARRAY_WORDS, TIMEOUT_CYCLES -- both derived from
                                // bubble_sort_program.py's actual ARRAY, so this
                                // file never needs manual edits when N changes

// ===========================================================================
// Day 86: System-Level Harness
// Wraps riscv_core (unchanged since Day 85) with imem/dmem and runs a real,
// hand-assembled RV32I program (bubble sort of an 8-element array) to
// completion. Correctness is still checked instruction-by-instruction against
// the golden trace (as in Day 85), but that detail is verified SILENTLY --
// only the final array, pass/fail, and the measured CPI are printed.
// ===========================================================================
module tb_riscv_core;

    // -----------------------------------------------------------------
    // Clock / Reset
    // -----------------------------------------------------------------
    reg clk = 0;
    reg nreset;
    always #5 clk = ~clk;  // 100 MHz

    // -----------------------------------------------------------------
    // DUT interconnect
    // -----------------------------------------------------------------
    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_wstrb;
    wire        dmem_en;
    wire        retired_valid;
    wire [4:0]  retired_rd;
    wire [31:0] retired_data;
    wire        trap_load_misaligned, trap_store_misaligned;

    riscv_core dut (
        .clk                  (clk),
        .nreset               (nreset),
        .imem_addr            (imem_addr),
        .imem_rdata           (imem_rdata),
        .dmem_addr            (dmem_addr),
        .dmem_wdata           (dmem_wdata),
        .dmem_wstrb           (dmem_wstrb),
        .dmem_en              (dmem_en),
        .dmem_rdata           (dmem_rdata),
        .retired_valid        (retired_valid),
        .retired_rd           (retired_rd),
        .retired_data         (retired_data),
        .trap_load_misaligned (trap_load_misaligned),
        .trap_store_misaligned(trap_store_misaligned)
    );

    localparam IMEM_DEPTH  = 256;
    localparam DMEM_DEPTH  = 256;   // words -> 1024 bytes, matches the golden model
    localparam ARRAY_WORDS = `ARRAY_WORDS;  // elements sorted, at dmem word[0..N-1]

    // Original (pre-sort) values, loaded purely for the final printout --
    // dmem itself gets overwritten in place by the sort.
    reg [31:0] unsorted_arr [0:ARRAY_WORDS-1];
    initial $readmemh("unsorted_array.mem", unsorted_arr);

    instruction_mem #(
        .MEM_DEPTH(IMEM_DEPTH),
        .MEM_FILE("program.mem")
    ) u_imem (
        .addr (imem_addr),
        .rdata(imem_rdata)
    );

    riscv_data_mem #(
        .MEM_DEPTH(DMEM_DEPTH)
    ) u_dmem (
        .clk  (clk),
        .en   (dmem_en),
        .wstrb(dmem_wstrb),
        .addr (dmem_addr),
        .wdata(dmem_wdata),
        .rdata(dmem_rdata)
    );

    // -----------------------------------------------------------------
    // Golden retirement trace (silent correctness check -- same mechanism
    // as Day 85, but nothing is printed per-instruction; only a final
    // pass/fail tally is reported).
    // -----------------------------------------------------------------
    reg [69:0] expected_mem [0:`EXPECTED_COUNT-1];
    integer retire_idx;
    integer retire_errors;
    reg     retire_done;

    reg [31:0] exp_pc;
    reg [4:0]  exp_rd;
    reg [31:0] exp_data;
    reg        exp_write;

    initial begin
        $readmemh("expected_trace.mem", expected_mem);
        retire_idx    = 0;
        retire_errors = 0;
        retire_done   = 0;
    end

    always @(negedge clk) begin
        if (nreset && retired_valid && !retire_done) begin
            exp_write = expected_mem[retire_idx][69];
            exp_rd    = expected_mem[retire_idx][68:64];
            exp_pc    = expected_mem[retire_idx][63:32];
            exp_data  = expected_mem[retire_idx][31:0];

            if (exp_write && ((retired_rd !== exp_rd) || (retired_data !== exp_data))) begin
                retire_errors = retire_errors + 1;
            end

            retire_idx = retire_idx + 1;
            if (retire_idx == `EXPECTED_COUNT) retire_done = 1;
        end
    end

    // -----------------------------------------------------------------
    // Performance counters: total cycles vs. total retired instructions
    // -----------------------------------------------------------------
    integer cycle_count;
    integer retired_count;

    initial begin
        cycle_count   = 0;
        retired_count = 0;
    end

    always @(posedge clk) if (nreset) cycle_count = cycle_count + 1;
    always @(negedge clk) if (nreset && retired_valid) retired_count = retired_count + 1;

    // -----------------------------------------------------------------
    // Reset sequence + watchdog
    // -----------------------------------------------------------------
    localparam TIMEOUT_CYCLES = `TIMEOUT_CYCLES;

    initial begin
        nreset = 0;
        repeat (3) @(posedge clk);
        nreset = 1;
    end

    always @(posedge clk) begin
        if (cycle_count > TIMEOUT_CYCLES) begin
            $display("*** TIMEOUT: program did not finish within %0d cycles ***", TIMEOUT_CYCLES);
            $finish;
        end
    end

    // -----------------------------------------------------------------
    // Final report: fires once every expected instruction has retired.
    // This is the ONLY block that prints anything beyond the timeout/error
    // paths above -- clean, single-shot summary suitable for sharing.
    // -----------------------------------------------------------------
    integer i;
    reg [31:0] sorted_word;
    reg is_sorted;
    integer final_cycles, final_retired;
    reg     report_done;

    initial report_done = 0;

    // Single process handles the freeze-and-report sequence. Splitting this
    // across two always @(posedge clk) blocks that share the same guard is a
    // race (the LRM doesn't order two procedures triggered by the same edge)
    // -- it can pass at one N and silently read X counters at another, as it
    // did here between N=8 and N=12. One block makes the ordering explicit.
    always @(posedge clk) begin
        if (retire_done && !report_done) begin
            // Freeze the performance counters at the exact cycle the golden-
            // matched program finishes retiring -- before the settle/drain
            // delay below, so CPI is over precisely `EXPECTED_COUNT` instrs.
            final_cycles  = cycle_count;
            final_retired = retired_count;
            report_done   = 1;
            repeat (5) @(posedge clk); // let the last dmem write settle

            is_sorted = 1;
            for (i = 0; i < ARRAY_WORDS - 1; i = i + 1) begin
                if (u_dmem.mem[i] > u_dmem.mem[i+1]) is_sorted = 0;
            end

            $display("");
            $display("================= Day 86: RV32I Core Running Bubble Sort =================");
            $write  ("Unsorted input :");
            for (i = 0; i < ARRAY_WORDS; i = i + 1) $write(" %0d", unsorted_arr[i]);
            $display("");
            $write  ("Sorted output  :");
            for (i = 0; i < ARRAY_WORDS; i = i + 1) $write(" %0d", u_dmem.mem[i]);
            $display("");
            $display("Result         : %s", is_sorted ? "CORRECTLY SORTED" : "*** SORT FAILED ***");
            $display("Instruction-level check: %0d/%0d retirements matched golden model (%s)",
                      (`EXPECTED_COUNT - retire_errors), `EXPECTED_COUNT,
                      (retire_errors == 0) ? "PASS" : "FAIL");
            $display("---------------------------------------------------------------------------");
            $display("Total cycles          : %0d", final_cycles);
            $display("Retired instructions  : %0d", final_retired);
            $display("CPI (cycles/instr)    : %0d.%02d", final_cycles / final_retired,
                      ((final_cycles * 100) / final_retired) % 100);
            $display("===========================================================================");
            $display("");
            $finish;
        end
    end

    // Waveform dump (kept for debugging; not required to read the summary)
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_riscv_core);
    end

endmodule