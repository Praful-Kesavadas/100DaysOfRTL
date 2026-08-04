`timescale 1ns / 1ps

module tb_asyn_fifo();

    parameter DEPTH      = 16;
    parameter DATA_WIDTH = 8;
    parameter WR_PERIOD  = 10; // 100 MHz Write Clock
    parameter RD_PERIOD  = 25; // 40 MHz Read Clock

    reg                  wr_clk, wr_rst_n, wr_en;
    reg  [DATA_WIDTH-1:0] data_in;
    wire                 full;

    reg                  rd_clk, rd_rst_n, rd_en;
    wire [DATA_WIDTH-1:0] data_out;
    wire                 empty;

    integer errors = 0;
    integer i;

    // Instantiate Asynchronous FIFO
    asyn_fifo #(
        .DEPTH(DEPTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .wr_clk(wr_clk), .wr_rst_n(wr_rst_n), .wr_en(wr_en), .data_in(data_in), .full(full),
        .rd_clk(rd_clk), .rd_rst_n(rd_rst_n), .rd_en(rd_en), .data_out(data_out), .empty(empty)
    );

    // Generate Independent Asynchronous Clocks
    always #(WR_PERIOD / 2) wr_clk = ~wr_clk;
    always #(RD_PERIOD / 2) rd_clk = ~rd_clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        wr_clk   = 0; wr_rst_n = 0; wr_en = 0; data_in = 0;
        rd_clk   = 0; rd_rst_n = 0; rd_en = 0;

        // Apply Active-Low Reset to both domains
        #(WR_PERIOD * 2);
        wr_rst_n = 1; rd_rst_n = 1;
        #(WR_PERIOD * 2);

        $display("\n====================================================");
        $display("   DAY 56: ASYNCHRONOUS DUAL-CLOCK FIFO VERIFICATION");
        $display("   wr_clk = 100 MHz | rd_clk = 40 MHz");
        $display("====================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Check Initial Reset State
        // -------------------------------------------------------------
        if (empty && !full) begin
            $display("[PASS] TEST 1: Reset State Verified (EMPTY = 1, FULL = 0).");
        end else begin
            $display("[FAIL] TEST 1: Reset flag state mismatch!");
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 2: High-Speed Burst Write at 100 MHz (16 entries)
        // -------------------------------------------------------------
        $display("\n--- TEST 2: High-Speed Burst Write (100 MHz) ---");
        for (i = 1; i <= DEPTH; i = i + 1) begin
            @(negedge wr_clk);
            wr_en   = 1;
            data_in = i[7:0];
        end

        @(negedge wr_clk);
        wr_en = 0; // Deassert write strobe

        // Allow 2FF synchronization latency cycles for full flag to update
        #(WR_PERIOD * 3);
        if (full) begin
            $display("[PASS] TEST 2: FIFO accurately asserted FULL flag across CDC boundary.");
        end else begin
            $display("[FAIL] TEST 2: FULL flag failed to assert!");
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 3: Slow Consumer Read at 40 MHz & Verify Data Integrity
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Slow Consumer Drain (40 MHz) & Data Ordering ---");
        for (i = 1; i <= DEPTH; i = i + 1) begin
            @(negedge rd_clk);
            rd_en = 1;

            @(posedge rd_clk); #1;
            if (data_out === i[7:0]) begin
                $display("[PASS] Sample %2d Read: 0x%02h", i, data_out);
            end else begin
                $display("[FAIL] Data Mismatch at sample %0d! Got 0x%02h, Exp 0x%02h", i, data_out, i[7:0]);
                errors = errors + 1;
            end
        end

        @(negedge rd_clk);
        rd_en = 0; // Deassert read strobe

        // Allow 2FF synchronization latency cycles for empty flag to update
        #(RD_PERIOD * 3);
        if (empty) begin
            $display("[PASS] TEST 3: FIFO cleanly returned to EMPTY state.");
        end else begin
            $display("[FAIL] TEST 3: EMPTY flag failed to assert!");
            errors = errors + 1;
        end

        // SUMMARY
        $display("\n====================================================");
        if (errors == 0) $display(" ALL ASYNCHRONOUS CDC FIFO TESTS PASSED!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");

        $finish;
    end

endmodule