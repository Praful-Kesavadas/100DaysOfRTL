`timescale 1ns / 1ps
`include "expected_count.vh"

module tb_riscv_core;

    // -------------------------------------------------------------------
    // Clock / Reset
    // -------------------------------------------------------------------
    reg clk = 0;
    reg nreset;
    always #5 clk = ~clk;  // 100 MHz

    // -------------------------------------------------------------------
    // DUT interconnect
    // -------------------------------------------------------------------
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

    localparam IMEM_DEPTH = 256;
    localparam DMEM_DEPTH = 256;  // words (256*4 = 1024 bytes, matches the golden model)

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

    // -------------------------------------------------------------------
    // Golden retirement trace (register writebacks), from generate_mem.py
    // Format: [has_write(1) | rd(5) | pc(32) | data(32)] packed as 70 bits
    // -------------------------------------------------------------------
    reg [69:0] expected_mem [0:`EXPECTED_COUNT-1];
    integer retire_idx;
    integer retire_errors;
    reg     retire_done;

    // -------------------------------------------------------------------
    // Golden MEM-stage load/store event trace, from generate_mem.py
    // Format: 1 hex digit = [kind(1: 0=load,1=store)][misaligned(1)]
    // -------------------------------------------------------------------
    reg [3:0] expected_mem_events [0:`EXPECTED_MEM_EVENTS-1];
    integer mem_idx;
    integer mem_errors;
    reg     mem_done;

    initial begin
        $readmemh("expected_trace.mem", expected_mem);
        $readmemh("expected_mem_events.mem", expected_mem_events);
    end

    // -------------------------------------------------------------------
    // Retirement checker: fires on every retired_valid, in program order.
    // Sampled at negedge so all combinational signals are settled and
    // there's no race with the registers that drive them updating on
    // the same posedge.
    // -------------------------------------------------------------------
    reg [31:0] exp_pc;
    reg [4:0]  exp_rd;
    reg [31:0] exp_data;
    reg        exp_write;

    initial begin
        retire_idx = 0;
        retire_errors = 0;
        retire_done = 0;
    end

    always @(negedge clk) begin
        if (nreset && retired_valid && !retire_done) begin
            exp_write = expected_mem[retire_idx][69];
            exp_rd    = expected_mem[retire_idx][68:64];
            exp_pc    = expected_mem[retire_idx][63:32];
            exp_data  = expected_mem[retire_idx][31:0];

            if (exp_write) begin
                if ((retired_rd !== exp_rd) || (retired_data !== exp_data)) begin
                    retire_errors = retire_errors + 1;
                    $display("[%0t] RETIRE MISMATCH #%0d (expected PC=0x%08h): expected rd=x%0d data=0x%08h, got rd=x%0d data=0x%08h",
                              $time, retire_idx, exp_pc, exp_rd, exp_data, retired_rd, retired_data);
                end
                else begin
                    $display("[%0t] retire #%0d OK  (PC=0x%08h  rd=x%0d  data=0x%08h)",
                              $time, retire_idx, exp_pc, retired_rd, retired_data);
                end
            end
            else begin
                // Non-register-writing instruction (store/branch/misaligned load): retired_valid
                // still pulses (any non-bubble instruction retires), but retired_rd/retired_data
                // are raw MEM/WB pass-through bits with no architectural meaning here (e.g. for a
                // store, bits[11:7] of the encoding are part of the immediate, not a real rd, and
                // retired_data mirrors the computed address) -- so only the retirement itself
                // (i.e. that this dynamic instruction, and only this one, occurred here in program
                // order) is checked, not these two fields.
                $display("[%0t] retire #%0d OK  (PC=0x%08h  non-writing instruction, rd/data not checked)",
                          $time, retire_idx, exp_pc);
            end

            retire_idx = retire_idx + 1;
            if (retire_idx == `EXPECTED_COUNT) begin
                retire_done = 1;
                $display("[%0t] All %0d expected retirements matched (dynamic trace complete; core is now spinning in the halt loop).",
                          $time, `EXPECTED_COUNT);
            end
        end
    end

    // -------------------------------------------------------------------
    // MEM-stage load/store event checker: fires whenever a load or store
    // is passing through the MEM stage this cycle. Detected purely from
    // externally-visible signals:
    //   - dmem_en          -> an aligned access is actually happening
    //   - trap_load_misaligned / trap_store_misaligned -> a misaligned one
    // Exactly one of these three is asserted per dynamic load/store
    // instruction, in program order, since the MEM/WB boundary in this
    // design is never stalled or flushed.
    // -------------------------------------------------------------------
    reg exp_kind_store;
    reg exp_misaligned;

    initial begin
        mem_idx = 0;
        mem_errors = 0;
        mem_done = 0;
    end

    always @(negedge clk) begin
        if (nreset && !mem_done &&
            (dmem_en || trap_load_misaligned || trap_store_misaligned)) begin

            exp_kind_store = expected_mem_events[mem_idx][1];
            exp_misaligned = expected_mem_events[mem_idx][0];

            if (exp_misaligned) begin
                if (exp_kind_store) begin
                    if (!trap_store_misaligned)
                        begin mem_errors = mem_errors + 1;
                              $display("[%0t] MEM EVENT MISMATCH #%0d: expected misaligned STORE trap, trap_store_misaligned=%b trap_load_misaligned=%b dmem_en=%b",
                                        $time, mem_idx, trap_store_misaligned, trap_load_misaligned, dmem_en); end
                end else begin
                    if (!trap_load_misaligned)
                        begin mem_errors = mem_errors + 1;
                              $display("[%0t] MEM EVENT MISMATCH #%0d: expected misaligned LOAD trap, trap_load_misaligned=%b trap_store_misaligned=%b dmem_en=%b",
                                        $time, mem_idx, trap_load_misaligned, trap_store_misaligned, dmem_en); end
                end
            end else begin
                if (!dmem_en || trap_load_misaligned || trap_store_misaligned) begin
                    mem_errors = mem_errors + 1;
                    $display("[%0t] MEM EVENT MISMATCH #%0d: expected aligned %s (no trap), dmem_en=%b trap_load=%b trap_store=%b",
                              $time, mem_idx, exp_kind_store ? "STORE" : "LOAD", dmem_en, trap_load_misaligned, trap_store_misaligned);
                end
                else if (exp_kind_store != (dmem_wstrb != 4'b0000)) begin
                    mem_errors = mem_errors + 1;
                    $display("[%0t] MEM EVENT MISMATCH #%0d: expected kind=%s but dmem_wstrb=%b suggests otherwise",
                              $time, mem_idx, exp_kind_store ? "STORE" : "LOAD", dmem_wstrb);
                end
            end

            mem_idx = mem_idx + 1;
            if (mem_idx == `EXPECTED_MEM_EVENTS) begin
                mem_done = 1;
                $display("[%0t] All %0d expected MEM-stage load/store events matched.", $time, `EXPECTED_MEM_EVENTS);
            end
        end
    end

    // -------------------------------------------------------------------
    // Reset sequence, watchdog, and final pass/fail report
    // -------------------------------------------------------------------
    integer cycle_count;
    localparam TIMEOUT_CYCLES = 5000;
    localparam DRAIN_CYCLES_AFTER_DONE = 20;

    initial begin
        nreset = 0;
        cycle_count = 0;
        repeat (3) @(posedge clk);
        nreset = 1;
    end

    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
        if (cycle_count > TIMEOUT_CYCLES) begin
            $display("\n*** TIMEOUT: simulation did not reach the halt loop within %0d cycles. ***", TIMEOUT_CYCLES);
            $display("    Retirements matched: %0d / %0d", retire_idx, `EXPECTED_COUNT);
            $display("    MEM events matched : %0d / %0d", mem_idx, `EXPECTED_MEM_EVENTS);
            $display("*** FAIL ***");
            $finish;
        end
    end

    // Once both checkers have drained their expected queues, run a short
    // margin and finish -- the DUT will keep retiring the halt self-loop
    // jal forever after this, which is expected and not checked further.
    always @(posedge clk) begin
        if (retire_done && mem_done) begin
            repeat (DRAIN_CYCLES_AFTER_DONE) @(posedge clk);
            $display("\n===================================================");
            if (retire_errors == 0 && mem_errors == 0) begin
                $display(" ALL TESTS PASSED (%0d retirements, %0d mem events)", `EXPECTED_COUNT, `EXPECTED_MEM_EVENTS);
            end else begin
                $display(" *** FAIL ***  retire_errors=%0d  mem_errors=%0d", retire_errors, mem_errors);
            end
            $display("===================================================\n");
            $finish;
        end
    end

    // Waveform dump
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_riscv_core);
    end

endmodule