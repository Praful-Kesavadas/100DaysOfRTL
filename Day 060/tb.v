`timescale 1ns / 1ps

module tb_ieee754_multiplier_fsm();

    parameter CLK_PERIOD = 10;

    reg        clk;
    reg        nreset;
    reg        start;
    reg [31:0] A, B;
    wire [31:0] result;
    wire       valid, underflow, overflow, zero;

    integer errors = 0;

    // Instantiate Multi-Cycle FSM Core
    ieee754_multiplier_fsm uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .A(A),
        .B(B),
        .result(result),
        .valid(valid),
        .underflow(underflow),
        .overflow(overflow),
        .zero(zero)
    );

    // 100 MHz Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk    = 0;
        nreset = 0;
        start  = 0;
        A      = 0;
        B      = 0;

        #(CLK_PERIOD * 2);
        nreset = 1;
        #(CLK_PERIOD);

        $display("\n====================================================");
        $display("   DAY 60: FSM FP32 MULTIPLIER CORE VERIFICATION");
        $display("====================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Standard Multiplication (3.0 * 4.0 = 12.0)
        // -------------------------------------------------------------
        $display("--- TEST 1: Standard Multiplication (3.0 * 4.0 = 12.0) ---");
        @(negedge clk);
        start = 1;
        A = 32'h4040_0000; // +3.0
        B = 32'h4080_0000; // +4.0
        @(negedge clk); start = 0;

        wait(valid); #1;
        if (result === 32'h4140_0000)
            $display("[PASS] 3.0 * 4.0 = 12.0 (Hex: 0x%08h)", result);
        else begin
            $display("[FAIL] Expected 0x41400000, Got 0x%08h", result);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 2: Mantissa Overflow (1.5 * 1.5 = 2.25) -> Bit 47 Shift
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Mantissa Shift Check (1.5 * 1.5 = 2.25) ---");
        @(negedge clk);
        start = 1;
        A = 32'h3FC0_0000; // +1.5
        B = 32'h3FC0_0000; // +1.5
        @(negedge clk); start = 0;

        wait(valid); #1;
        if (result === 32'h4010_0000)
            $display("[PASS] 1.5 * 1.5 = 2.25 (Hex: 0x%08h)", result);
        else begin
            $display("[FAIL] Expected 0x40100000, Got 0x%08h", result);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 3: Zero Input (-0.0 * 25.5 = 0.0) -> Zero Flag
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Zero Operand Multiplication (-0.0 * 25.5 = 0.0) ---");
        @(negedge clk);
        start = 1;
        A = 32'h8000_0000; // -0.0
        B = 32'h41CC_0000; // +25.5
        @(negedge clk); start = 0;

        wait(valid); #1;
        if (result === 32'h0000_0000 && zero)
            $display("[PASS] -0.0 * 25.5 = 0.0 (Hex: 0x%08h, Zero Flag Z=%0d)", result, zero);
        else begin
            $display("[FAIL] Expected 0x00000000 (Z=1), Got 0x%08h (zero=%b)", result, zero);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 4: Exponent Overflow (Max FP32 * 2.0 -> Infinity)
        // -------------------------------------------------------------
        $display("\n--- TEST 4: Exponent Overflow Check ---");
        @(negedge clk);
        start = 1;
        A = 32'h7F7F_FFFF; // ~3.4028235e38
        B = 32'h4000_0000; // +2.0
        @(negedge clk); start = 0;

        wait(valid); #1;
        if (overflow && result[30:23] == 8'hFF)
            $display("[PASS] Overflow detected correctly! (Hex: 0x%08h, Overflow Flag V=%0d)", result, overflow);
        else begin
            $display("[FAIL] Expected Overflow V=1, Got V=%b (Result: 0x%08h)", overflow, result);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 5: Exponent Underflow (Small * Small -> Flush to 0)
        // -------------------------------------------------------------
        $display("\n--- TEST 5: Exponent Underflow Check ---");
        @(negedge clk);
        start = 1;
        A = 32'h00C0_0000; // ~1.5 * 2^-126 (Smallest exponent E=1)
        B = 32'h3F00_0000; // +0.5 (Exponent E=126)
        @(negedge clk); start = 0;

        wait(valid); #1;
        if (underflow)
            $display("[PASS] Underflow detected correctly! (Hex: 0x%08h, Underflow Flag U=%0d)", result, underflow);
        else begin
            $display("[FAIL] Expected Underflow U=1, Got U=%b (Result: 0x%08h)", underflow, result);
            errors = errors + 1;
        end

        // SUMMARY
        $display("\n====================================================");
        if (errors == 0) $display(" ALL MULTI-CYCLE FSM FP32 MULTIPLIER TESTS PASSED!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");

        #20;
        $finish;
    end

endmodule