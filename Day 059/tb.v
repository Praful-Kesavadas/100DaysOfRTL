`timescale 1ns / 1ps

module tb_ieee754_adder_fsm();

    parameter CLK_PERIOD = 10;

    reg        clk;
    reg        nreset;
    reg        start;
    reg        sub;
    wire       valid;
    reg [31:0] A, B;
    wire [31:0] result;
    wire       overflow, underflow, zero;

    integer errors = 0;

    // Instantiate FSM Core
    ieee754_adder_fsm uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .sub(sub),
        .valid(valid),
        .A(A),
        .B(B),
        .result(result),
        .overflow(overflow),
        .underflow(underflow),
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
        sub    = 0;
        A      = 0;
        B      = 0;

        #(CLK_PERIOD * 2);
        nreset = 1;
        #(CLK_PERIOD);

        $display("\n====================================================");
        $display("   DAY 59: FSM FP32 ADDER CORE FULL VERIFICATION");
        $display("====================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Standard Addition (16.0 + 6.0 = 22.0)
        // -------------------------------------------------------------
        $display("--- TEST 1: Addition (16.0 + 6.0 = 22.0) ---");
        @(negedge clk);
        start = 1; sub = 0;
        A = 32'h4180_0000; // +16.0
        B = 32'h40C0_0000; // +6.0
        @(negedge clk); start = 0;

        wait(valid); #1;
        if (result === 32'h41B0_0000)
            $display("[PASS] 16.0 + 6.0 = 22.0 (Hex: 0x%08h)", result);
        else begin
            $display("[FAIL] Expected 0x41B00000, Got 0x%08h", result);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 2: Exact Zero Result (20.0 - 20.0 = 0.0) -> Tests Zero Flag
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Subtraction to Zero (20.0 - 20.0 = 0.0) ---");
        @(negedge clk);
        start = 1; sub = 1; // Perform A - B
        A = 32'h41A0_0000; // +20.0
        B = 32'h41A0_0000; // +20.0
        @(negedge clk); start = 0;

        wait(valid); #1;
        if (result === 32'h0000_0000 && zero)
            $display("[PASS] 20.0 - 20.0 = 0.0 (Hex: 0x%08h, Zero Flag Z=%0d)", result, zero);
        else begin
            $display("[FAIL] Expected 0x00000000, Got 0x%08h (zero=%b)", result, zero);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 3: Catastrophic Cancellation (1.5 - 1.25 = 0.25) -> LZC Check
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Normalization Check (1.5 - 1.25 = 0.25) ---");
        @(negedge clk);
        start = 1; sub = 0;
        A = 32'h3FC0_0000; // +1.5
        B = 32'hBFA0_0000; // -1.25
        @(negedge clk); start = 0;

        wait(valid); #1;
        if (result === 32'h3E80_0000)
            $display("[PASS] 1.5 + (-1.25) = 0.25 (Hex: 0x%08h)", result);
        else begin
            $display("[FAIL] Expected 0x3E800000 (0.25), Got 0x%08h", result);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 4: Overflow Check (Max Float + Max Float -> Infinity)
        // -------------------------------------------------------------
        $display("\n--- TEST 4: Overflow Check (Max FP32 + Max FP32) ---");
        @(negedge clk);
        start = 1; sub = 0;
        A = 32'h7F7F_FFFF; // ~3.4028235e38 (Max Normal FP32)
        B = 32'h7F7F_FFFF; // ~3.4028235e38
        @(negedge clk); start = 0;

        wait(valid); #1;
        if (overflow)
            $display("[PASS] Overflow detected correctly! (Hex: 0x%08h, Overflow Flag V=%0d)", result, overflow);
        else begin
            $display("[FAIL] Expected Overflow flag V=1, Got V=%b (Result: 0x%08h)", overflow, result);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 5: Underflow Check (Exponent underflows past E=1)
        // -------------------------------------------------------------
        $display("\n--- TEST 5: Underflow Check (Min Normal Subtraction) ---");
        @(negedge clk);
        start = 1; sub = 1;
        A = 32'h00C0_0000; // 1.5 * 2^-126 (Exp = 1)
        B = 32'h00B8_0000; // 1.4375 * 2^-126 (Exp = 1)
        @(negedge clk); start = 0;

        wait(valid); #1;
        if (underflow)
            $display("[PASS] Underflow detected correctly! (Hex: 0x%08h, Underflow Flag U=%0d)", result, underflow);
        else begin
            $display("[FAIL] Expected Underflow flag U=1, Got U=%b (Result: 0x%08h)", underflow, result);
            errors = errors + 1;
        end

        // SUMMARY
        $display("\n====================================================");
        if (errors == 0) $display(" ALL MULTI-CYCLE FSM FP32 ADDER TESTS PASSED!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");
        #20;
        $finish;
    end

endmodule