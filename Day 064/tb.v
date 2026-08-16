`timescale 1ns / 1ps

module tb_fixed_point_matrix_multiplier();

    parameter CLK_PERIOD = 10;
    parameter DATA_WIDTH = 16;
    parameter FRAC_WIDTH = 8; // Q8.8 Format: 1.0 = 16'h0100 (256)

    reg                             clk;
    reg                             nreset;
    reg                             start;

    reg  signed [DATA_WIDTH-1:0]    a00, a01, a10, a11;
    reg  signed [DATA_WIDTH-1:0]    b00, b01, b10, b11;

    wire signed [DATA_WIDTH-1:0]    c00, c01, c10, c11;
    wire                            valid;

    integer errors = 0;

    // Helper functions for Q8.8 fixed-point conversion
    function signed [15:0] to_q(input real val);
        to_q = $rtoi(val * 256.0);
    endfunction

    function real from_q(input signed [15:0] val);
        from_q = val / 256.0;
    endfunction

    // Instantiate Matrix Multiplier Core
    fixed_point_matrix_multiplier #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .a00(a00), .a01(a01), .a10(a10), .a11(a11),
        .b00(b00), .b01(b01), .b10(b10), .b11(b11),
        .c00(c00), .c01(c01), .c10(c10), .c11(c11),
        .valid(valid)
    );

    // 100 MHz Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Modular Task to Run and Display Matrix Multiplication Tests
    task run_test(
        input [4*127:0] test_name,
        input real in_a00, input real in_a01,
        input real in_a10, input real in_a11,
        input real in_b00, input real in_b01,
        input real in_b10, input real in_b11,
        input real exp_c00, input real exp_c01,
        input real exp_c10, input real exp_c11
    );
        reg signed [15:0] exp_q_c00, exp_q_c01, exp_q_c10, exp_q_c11;
        begin
            exp_q_c00 = to_q(exp_c00);
            exp_q_c01 = to_q(exp_c01);
            exp_q_c10 = to_q(exp_c10);
            exp_q_c11 = to_q(exp_c11);

            @(negedge clk);
            start = 1;
            a00 = to_q(in_a00); a01 = to_q(in_a01);
            a10 = to_q(in_a10); a11 = to_q(in_a11);
            b00 = to_q(in_b00); b01 = to_q(in_b01);
            b10 = to_q(in_b10); b11 = to_q(in_b11);
            @(negedge clk);
            start = 0;

            wait(valid); #1;

            $display("----------------------------------------------------");
            $display("TEST: %0s", test_name);
            $display("Matrix A:                  Matrix B:");
            $display("[ %7.3f  %7.3f ]    x    [ %7.3f  %7.3f ]", in_a00, in_a01, in_b00, in_b01);
            $display("[ %7.3f  %7.3f ]         [ %7.3f  %7.3f ]", in_a10, in_a11, in_b10, in_b11);
            $display("Expected Result Matrix C:  Actual Output Matrix C:");
            $display("[ %7.3f  %7.3f ]         [ %7.3f  %7.3f ]", exp_c00, exp_c01, from_q(c00), from_q(c01));
            $display("[ %7.3f  %7.3f ]         [ %7.3f  %7.3f ]", exp_c10, exp_c11, from_q(c10), from_q(c11));

            if ((c00 === exp_q_c00) && (c01 === exp_q_c01) &&
                (c10 === exp_q_c10) && (c11 === exp_q_c11)) begin
                $display("--> [PASS] Match verified!");
            end else begin
                $display("--> [FAIL] MISMATCH DETECTED!");
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk    = 0;
        nreset = 0;
        start  = 0;
        {a00, a01, a10, a11} = 0;
        {b00, b01, b10, b11} = 0;

        #(CLK_PERIOD * 2);
        nreset = 1;
        #(CLK_PERIOD);

        $display("\n====================================================");
        $display("   DAY 64: 2x2 FIXED-POINT MATRIX MULTIPLIER TESTS   ");
        $display("====================================================");

        // TEST 1: Identity Matrix Neutral Check (A * I = A)
        run_test(
            "1. Identity Matrix Multiplication (A * I)",
            1.50, -2.00,
            0.50,  3.00,
            1.00,  0.00,
            0.00,  1.00,
            1.50, -2.00,
            0.50,  3.00
        );

        // TEST 2: General Fractional & Signed Arithmetic
        run_test(
            "2. Signed & Fractional Multiplication",
             1.25,  0.50,
            -1.00,  2.00,
             2.00, -1.50,
             0.50,  1.00,
             2.75, -1.375,
            -1.00,  3.500
        );

        // TEST 3 (Corner Case): Zero Matrix Neutral Check (A * 0 = 0)
        run_test(
            "3. Zero Matrix Corner Case (A * 0)",
             3.25, -4.50,
             2.00, -1.75,
             0.00,  0.00,
             0.00,  0.00,
             0.00,  0.00,
             0.00,  0.00
        );

        // TEST 4 (Corner Case): All-Negative Matrix Multiplication
        // C = [ (-1.5*-2.0 + -0.5*-0.5) , (-1.5*-1.0 + -0.5*-3.0) ; (-2.0*-2.0 + -1.0*-0.5) , (-2.0*-1.0 + -1.0*-3.0) ]
        //   = [ (3.0 + 0.25) , (1.5 + 1.5) ; (4.0 + 0.5) , (2.0 + 3.0) ]
        //   = [ 3.25, 3.00 ; 4.50, 5.00 ]
        run_test(
            "4. All-Negative Elements Corner Case",
            -1.50, -0.50,
            -2.00, -1.00,
            -2.00, -1.00,
            -0.50, -3.00,
             3.25,  3.00,
             4.50,  5.00
        );

        // TEST 5 (Corner Case): Small Fractional Precision (1/8, 1/16, 1/32)
        // A = [ 0.125, 0.0625 ; 0.25, -0.125 ], B = [ 0.5, 0.25 ; -0.5, 0.125 ]
        // C00 = (0.125 * 0.5) + (0.0625 * -0.5) = 0.0625 - 0.03125 = 0.03125
        // C01 = (0.125 * 0.25) + (0.0625 * 0.125) = 0.03125 + 0.0078125 = 0.0390625
        // C10 = (0.25 * 0.5) + (-0.125 * -0.5) = 0.125 + 0.0625 = 0.1875
        // C11 = (0.25 * 0.25) + (-0.125 * 0.125) = 0.0625 - 0.015625 = 0.046875
        run_test(
            "5. Sub-Unit Fractional Precision LSBs",
            0.1250,  0.06250,
            0.2500, -0.12500,
            0.5000,  0.25000,
           -0.5000,  0.12500,
            0.03125, 0.0390625,
            0.18750, 0.0468750
        );

        // FINAL SUMMARY
        $display("====================================================");
        if (errors == 0) $display(" ALL 2x2 FIXED-POINT MATRIX TESTS PASSED!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");

        #20;
        $finish;
    end

endmodule