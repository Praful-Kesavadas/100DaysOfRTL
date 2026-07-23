// ============================================================================
// Module Name  : tb_serial_frame_parity
// Project      : #100DaysOfRTL - Day 46
// Description  : Self-Checking Testbench for Serial Frame Parity Engine
// ============================================================================

`timescale 1ns / 1ps

module tb_serial_frame_parity();

    reg        clk;
    reg        nreset;
    reg        data_valid;
    reg        frame_start;
    reg        frame_end;
    reg        serial_bit_in;
    reg        parity_mode;

    wire       parity_error;
    wire       parity_valid;

    integer    error_count = 0;

    // Instantiate Unit Under Test
    serial_frame_parity uut (
        .clk(clk),
        .nreset(nreset),
        .data_valid(data_valid),
        .frame_start(frame_start),
        .frame_end(frame_end),
        .serial_bit_in(serial_bit_in),
        .parity_mode(parity_mode),
        .parity_error(parity_error),
        .parity_valid(parity_valid)
    );

    // 100 MHz Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ========================================================================
    // HELPER TASK: Send Serial Frame & Verify Output
    // ========================================================================
    task send_serial_frame;
        input [8*24-1:0] test_name;
        input [7:0]      payload;      // 8 payload bits
        input            parity_bit;   // 1 parity bit
        input            mode;         // 0 = EVEN, 1 = ODD
        input            expected_err; // Expected parity_error output
        integer i;
        begin
            $display("\n==================================================");
            $display("RUNNING: %0s, Bits Input: %b, Parity Bit: %b, Mode: %0s", test_name, payload, parity_bit, (mode == 0) ? "EVEN" : "ODD");
            $display("==================================================");

            // Set Mode
            @(negedge clk);
            parity_mode = mode;

            // Transmit 8 Data Bits
            for (i = 0; i < 8; i = i + 1) begin
                data_valid    = 1'b1;
                frame_start   = (i == 0); // Pulse frame_start on bit 0
                frame_end     = 1'b0;
                serial_bit_in = payload[i];
                @(negedge clk);
            end

            // Transmit Parity Bit
            frame_start   = 1'b0;
            frame_end     = 1'b1;        // Pulse frame_end on parity bit
            serial_bit_in = parity_bit;
            @(negedge clk);

            // Inter-frame Idle Cycle
            data_valid    = 1'b0;
            frame_end     = 1'b0;
            serial_bit_in = 1'b1;        // Noise / Idle High Line

            // Wait for verification pulse
            @(posedge clk);
            if (parity_valid) begin
                if (parity_error === expected_err) begin
                    $display("--> PASS: parity_error = %b (Expected: %b)", parity_error, expected_err);
                end else begin
                    $display("--> FAIL: parity_error = %b | Expected: %b", parity_error, expected_err);
                    error_count = error_count + 1;
                end
            end else begin
                $display("--> FAIL: parity_valid was not asserted!");
                error_count = error_count + 1;
            end
        end
    endtask

    // ========================================================================
    // MAIN TEST SEQUENCER
    // ========================================================================
    initial begin
        // Initialize Inputs
        nreset        = 1'b0;
        data_valid    = 1'b0;
        frame_start   = 1'b0;
        frame_end     = 1'b0;
        serial_bit_in = 1'b1;
        parity_mode   = 1'b0;

        #20;
        nreset = 1'b1;
        #10;

        // --------------------------------------------------------------------
        // TEST 1: EVEN Parity - Valid Frame
        // Payload: 8'b1011_0001 (4 ones -> Even). Parity = 0. Expected Error = 0.
        // --------------------------------------------------------------------
        send_serial_frame("Test 1: Valid Frame", 8'b1011_0001, 1'b0, 1'b0, 1'b0);

        // --------------------------------------------------------------------
        // TEST 2: EVEN Parity - Corrupted Frame (Single Bit Flip)
        // Payload: 8'b1011_0011 (5 ones -> Odd). Parity = 0. Expected Error = 1.
        // --------------------------------------------------------------------
        send_serial_frame("Test 2: Corrupted Frame", 8'b1011_0011, 1'b0, 1'b0, 1'b1);

        // --------------------------------------------------------------------
        // TEST 3: ODD Parity - Valid Frame
        // Payload: 8'b1100_1010 (4 ones -> Even). Parity = 1 (Total ones = 5 -> Odd).
        // Expected Error = 0.
        // --------------------------------------------------------------------
        send_serial_frame("Test 3: Valid Frame", 8'b1100_1010, 1'b1, 1'b1, 1'b0);

        // --------------------------------------------------------------------
        // TEST 4: ODD Parity - Corrupted Frame
        // Payload: 8'b1100_1010 (4 ones -> Even). Parity = 0 (Total ones = 4 -> Even).
        // Expected Error = 1.
        // --------------------------------------------------------------------
        send_serial_frame("Test 4: Corrupted Frame", 8'b1100_1010, 1'b0, 1'b1, 1'b1);

        // --------------------------------------------------------------------
        // TEST 5: Noise Immunity Test (data_valid = 0)
        // Toggling input while idle should NOT affect internal state or trigger valid
        // --------------------------------------------------------------------
        $display("\n==================================================");
        $display("RUNNING: Test 5: Line Noise / Idle Immunity Test");
        $display("==================================================");
        data_valid = 1'b0;
        repeat(5) begin
            serial_bit_in = $random;
            @(negedge clk);
        end
        if (!parity_valid) begin
            $display("--> PASS: Engine completely ignored idle line toggles.");
        end else begin
            $display("--> FAIL: Engine triggered on idle noise!");
            error_count = error_count + 1;
        end

        // --------------------------------------------------------------------
        // SUMMARY
        // --------------------------------------------------------------------
        $display("\n==================================================");
        if (error_count == 0) begin
            $display("ALL TEST CASES PASSED SUCCESSFULLY!");
        end else begin
            $display("TESTBENCH FAILED WITH %0d ERROR(S).", error_count);
        end
        $display("==================================================\n");

        $finish;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_serial_frame_parity);
    end

endmodule