// ============================================================================
// Module Name  : tb_crc32_generator
// Project      : #100DaysOfRTL - Day 45
// Description  : Self-Checking Testbench for 8-bit CRC-32 Generator Core
// Target Standard: IEEE 802.3 CRC-32 (Ethernet / ZIP / PNG)
// ============================================================================

`timescale 1ns / 1ps

module tb_crc32_generator();

    // Parameters
    localparam DATA_WIDTH = 8;
    localparam CRC_WIDTH  = 32;

    // Testbench Signals
    reg                   clk;
    reg                   nreset;
    reg                   init;
    reg                   data_valid;
    reg  [DATA_WIDTH-1:0] data_in;

    wire [CRC_WIDTH-1:0]  crc_out;
    wire [CRC_WIDTH-1:0]  crc_state;
    wire                  crc_valid;

    // Error Tracking Counter
    integer error_count = 0;

    // Instantiate Unit Under Test (UUT)
    crc32_generator #(
        .DATA_WIDTH(DATA_WIDTH),
        .CRC_WIDTH(CRC_WIDTH)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .init(init),
        .data_valid(data_valid),
        .data_in(data_in),
        .crc_out(crc_out),
        .crc_state(crc_state),
        .crc_valid(crc_valid)
    );

    // 100 MHz System Clock (10ns period)
    initial begin
        forever #5 clk = ~clk;
    end

    // ========================================================================
    // HELPER TASK: Send Byte Stream & Verify Output
    // ========================================================================
    task send_and_check_frame;
        input [8*16-1:0]       test_name;     // Name of test case for display
        input integer          num_bytes;     // Number of bytes in payload
        input [8*16-1:0]       payload_str;   // String byte data
        input [CRC_WIDTH-1:0]  expected_crc;  // Expected Golden CRC-32
        integer i;
        begin
            $display("\n==================================================");
            $display("RUNNING: %0s (Length: %0d bytes)", test_name, num_bytes);
            $display("==================================================");

            // Drive inputs on falling edge to avoid #0 simulator race conditions
            @(negedge clk);
            init       = 1'b1;
            data_valid = 1'b1;

            for (i = num_bytes - 1; i >= 0; i = i - 1) begin
                data_in = payload_str[i*8 +: 8];
                $display("[TX Byte %0d] Input: 8'h%h ('%c')", (num_bytes - i), data_in, data_in);
                
                @(negedge clk);
                init = 1'b0; // De-assert init after first byte
            end

            // End of Frame Stream: Stop driving data
            data_valid = 1'b0;
            data_in    = 8'h00;

            // Wait for crc_valid assertion
            @(posedge clk);
            while (!crc_valid) @(posedge clk);

            // Check Result
            if (crc_out == expected_crc) begin
                $display("--> PASS: Calculated CRC-32 = 32'h%h (Matches Expected)", crc_out);
            end else begin
                $display("--> FAIL: Calculated CRC-32 = 32'h%h | Expected = 32'h%h", 
                         crc_out, expected_crc);
                error_count = error_count + 1;
            end
        end
    endtask

    // ========================================================================
    // MAIN TEST SEQUENCER
    // ========================================================================
    initial begin
        // Initialize Signals
        nreset     = 1'b0;
        init       = 1'b0;
        data_valid = 1'b0;
        data_in    = 8'h00;
        clk = 0;

        // Apply Reset
        #20;
        nreset = 1'b1;
        #10;

        // --------------------------------------------------------------------
        // TEST CASE 1: Single Byte "1" (8'h31)
        // Expected Golden IEEE CRC-32: 32'h83DCEFB7
        // --------------------------------------------------------------------
        send_and_check_frame("Test 1: Single Byte '1'", 1, "1", 32'h83DCEFB7);
        #30;

        // --------------------------------------------------------------------
        // TEST CASE 2: Two Bytes "12" (8'h31, 8'h32)
        // Expected Golden IEEE CRC-32: 32'h4F5344CD
        // --------------------------------------------------------------------
        send_and_check_frame("Test 2: Two Bytes '12'", 2, "12", 32'h4F5344CD);
        #30;

        // --------------------------------------------------------------------
        // TEST CASE 3: Standard Benchmark "123456789" (IEEE 802.3 Baseline)
        // Expected Golden IEEE CRC-32: 32'hCBF43926
        // --------------------------------------------------------------------
        send_and_check_frame("Test 3: Benchmark '123456789'", 9, "123456789", 32'hCBF43926);
        #50;

        // --------------------------------------------------------------------
        // FINAL TEST SUMMARY
        // --------------------------------------------------------------------
        $display("\n==================================================");
        if (error_count == 0) begin
            $display(" ALL TEST CASES PASSED SUCCESSFULLY!");
        end else begin
            $display(" TESTBENCH FAILED WITH %0d ERROR(S).", error_count);
        end
        $display("==================================================\n");

        $finish;
    end

    // VCD Waveform Dump
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
    end

endmodule