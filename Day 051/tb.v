`timescale 1ns / 1ps

module tb_sram();

    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 16;
    parameter ADDR_WIDTH = $clog2(DEPTH);
    parameter CLK_PERIOD = 10;

    reg                  clk;
    reg                  chip_enable;
    reg                  write_enable;
    reg  [ADDR_WIDTH-1:0] addr;
    reg  [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] out;

    integer errors = 0;

    // Instantiate Unit Under Test (UUT)
    sram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .chip_enable(chip_enable),
        .write_enable(write_enable),
        .addr(addr),
        .data_in(data_in),
        .out(out)
    );

    // 100 MHz Clock
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk          = 0;
        chip_enable  = 0;
        write_enable = 0;
        addr         = 0;
        data_in      = 0;

        #(CLK_PERIOD * 2);

        $display("\n====================================================");
        $display("    DAY 51: SYNCHRONOUS SRAM VERIFICATION");
        $display("====================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Write Operation to Address 4
        // -------------------------------------------------------------
        $display("--- TEST 1: Write Operation ---");
        @(negedge clk);
        chip_enable  = 1;
        write_enable = 1;
        addr         = 4'h4;
        data_in      = 8'hA5;

        @(posedge clk); #1;
        $display("[INFO] Wrote 8'hA5 to Address 4");

        // -------------------------------------------------------------
        // TEST 2: Synchronous Read from Address 4 (1-Cycle Latency)
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Synchronous Read ---");
        @(negedge clk);
        write_enable = 0; // Switch to Read Mode
        addr         = 4'h4;

        @(posedge clk); #1; // Read data valid post clock edge
        if (out === 8'hA5) begin
            $display("[PASS] Read Success! Addr 4 = 8'h%h", out);
        end else begin
            $display("[FAIL] Read Mismatch! Expected 8'hA5, Got 8'h%h", out);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 3: READ_FIRST Read-During-Write Collision
        // Overwrite Addr 4 with 8'h3C while reading. 'out' MUST output OLD data (8'hA5)
        // -------------------------------------------------------------
        $display("\n--- TEST 3: READ_FIRST Collision Check ---");
        @(negedge clk);
        write_enable = 1;
        addr         = 4'h4;
        data_in      = 8'h3C;

        @(posedge clk); #1;
        if (out === 8'hA5) begin
            $display("[PASS] READ_FIRST Success! Output retained old value (8'hA5) during write.");
        end else begin
            $display("[FAIL] READ_FIRST Violation! Got 8'h%h", out);
            errors = errors + 1;
        end

        // Read again to verify the NEW value (8'h3C) was written
        @(negedge clk);
        write_enable = 0;
        addr         = 4'h4;

        @(posedge clk); #1;
        if (out === 8'h3C) begin
            $display("[PASS] New data correctly updated in memory: Addr 4 = 8'h%h", out);
        end else begin
            $display("[FAIL] New data write failed! Got 8'h%h", out);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 4: Chip Enable Disabled (Standby Mode)
        // -------------------------------------------------------------
        $display("\n--- TEST 4: Standby Mode (`chip_enable = 0`) ---");
        @(negedge clk);
        chip_enable  = 0;
        write_enable = 1;
        addr         = 4'h4;
        data_in      = 8'hFF; // Should be ignored

        @(posedge clk); #1;
        
        // Re-enable and read back Addr 4 to confirm 8'hFF was NOT written
        @(negedge clk);
        chip_enable  = 1;
        write_enable = 0;
        addr         = 4'h4;

        @(posedge clk); #1;
        if (out === 8'h3C) begin
            $display("[PASS] Standby verified! Write ignored when chip_enable = 0.");
        end else begin
            $display("[FAIL] Standby check failed! Memory updated to 8'h%h", out);
            errors = errors + 1;
        end

        // SUMMARY
        $display("\n====================================================");
        if (errors == 0) $display(" ALL SRAM TESTS PASSED SUCCESSFULLY!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");

        $finish;
    end

endmodule