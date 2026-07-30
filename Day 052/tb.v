`timescale 1ns / 1ps

module tb_dual_port_sram();

    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 16;
    parameter ADDR_WIDTH = $clog2(DEPTH);
    parameter CLK_PERIOD = 10;

    reg                  clk;
    reg                  write_en;
    reg  [ADDR_WIDTH-1:0] addr_write;
    reg  [DATA_WIDTH-1:0] data_in;

    reg                  read_en;
    reg  [ADDR_WIDTH-1:0] addr_read;
    wire [DATA_WIDTH-1:0] data_out;

    integer errors = 0;

    // Instantiate UUT
    dual_port_sram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .write_en(write_en),
        .addr_write(addr_write),
        .data_in(data_in),
        .read_en(read_en),
        .addr_read(addr_read),
        .data_out(data_out)
    );

    // 100 MHz Clock Generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk        = 0;
        write_en   = 0;
        addr_write = 0;
        data_in    = 0;
        read_en    = 0;
        addr_read  = 0;

        #(CLK_PERIOD * 2);

        $display("\n====================================================");
        $display("   DAY 52: SIMPLE DUAL-PORT SRAM VERIFICATION");
        $display("====================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Write to Addr 3 on Port A
        // -------------------------------------------------------------
        $display("--- TEST 1: Write Operation (Port A) ---");
        @(negedge clk);
        write_en   = 1;
        addr_write = 4'h3;
        data_in    = 8'hDE;

        @(posedge clk); #1;
        $display("[INFO] Wrote 8'hDE to Addr 3");

        // -------------------------------------------------------------
        // TEST 2: Concurrent Read (Addr 3) & Write (Addr 7)
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Concurrent Read & Write ---");
        @(negedge clk);
        // Port A Writes 8'hAD to Addr 7
        write_en   = 1;
        addr_write = 4'h7;
        data_in    = 8'hAD;

        // Port B Reads Addr 3
        read_en   = 1;
        addr_read = 4'h3;

        @(posedge clk); #1; // Sample post-clock outputs
        if (data_out === 8'hDE) begin
            $display("[PASS] Concurrent Read Success! Port B Addr 3 = 8'h%h", data_out);
        end else begin
            $display("[FAIL] Read Mismatch! Expected 8'hDE, Got 8'h%h", data_out);
            errors = errors + 1;
        end

        // Read back Addr 7 to confirm Port A write succeeded
        @(negedge clk);
        write_en  = 0;
        read_en   = 1;
        addr_read = 4'h7;

        @(posedge clk); #1;
        if (data_out === 8'hAD) begin
            $display("[PASS] Concurrent Write Success! Port B Addr 7 = 8'h%h", data_out);
        end else begin
            $display("[FAIL] Write Check Failed! Expected 8'hAD, Got 8'h%h", data_out);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 3: Same-Address Read/Write Collision (Addr 3)
        // Expected: READ_FIRST behavior (data_out gets old value 8'hDE)
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Collision Check (Same Address) ---");
        @(negedge clk);
        // Both ports target Address 3 simultaneously!
        write_en   = 1;
        addr_write = 4'h3;
        data_in    = 8'hCA; // Overwriting Addr 3 with 8'hCA

        read_en   = 1;
        addr_read = 4'h3;

        @(posedge clk); #1;
        if (data_out === 8'hDE) begin
            $display("[PASS] READ_FIRST Collision Verified! Output retained old value (8'hDE).");
        end else begin
            $display("[FAIL] Collision Mismatch! Got 8'h%h", data_out);
            errors = errors + 1;
        end

        // Read again on next cycle to confirm 8'hCA was updated
        @(negedge clk);
        write_en  = 0;
        read_en   = 1;
        addr_read = 4'h3;

        @(posedge clk); #1;
        if (data_out === 8'hCA) begin
            $display("[PASS] Memory correctly updated after collision: Addr 3 = 8'h%h", data_out);
        end else begin
            $display("[FAIL] Memory update failed! Got 8'h%h", data_out);
            errors = errors + 1;
        end

        // SUMMARY
        $display("\n====================================================");
        if (errors == 0) $display(" ALL DUAL-PORT SRAM TESTS PASSED!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");

        $finish;
    end

endmodule