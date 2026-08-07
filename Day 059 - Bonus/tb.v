`timescale 1ns / 1ps

module tb_ieee754_adder_pipelined();

    parameter CLK_PERIOD = 10;

    reg        clk;
    reg        nreset;
    reg        valid_in;
    reg        sub;
    wire       valid_out;
    reg [31:0] A, B;
    wire [31:0] result;
    wire       overflow, underflow, zero;

    integer errors = 0;

    // Instantiate Pipelined Core
    ieee754_adder_pipelined uut (
        .clk(clk),
        .nreset(nreset),
        .valid_in(valid_in),
        .sub(sub),
        .valid_out(valid_out),
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

        clk      = 0;
        nreset   = 0;
        valid_in = 0;
        sub      = 0;
        A        = 0;
        B        = 0;

        #(CLK_PERIOD * 2);
        nreset = 1;
        #(CLK_PERIOD);

        $display("\n====================================================");
        $display("   DAY 59 BONUS: PIPELINED FP32 ADDER STREAM TEST");
        $display("====================================================\n");

        // -------------------------------------------------------------
        // STREAMING INPUTS: Feed 5 operations on consecutive clock cycles!
        // -------------------------------------------------------------
        
        // Cycle 1: Standard Addition (16.0 + 6.0 = 22.0)
        @(negedge clk);
        valid_in = 1; sub = 0;
        A = 32'h4180_0000; B = 32'h40C0_0000;

        // Cycle 2: Subtraction to Zero (20.0 - 20.0 = 0.0)
        @(negedge clk);
        valid_in = 1; sub = 1;
        A = 32'h41A0_0000; B = 32'h41A0_0000;

        // Cycle 3: Normalization / LZC (1.5 + (-1.25) = 0.25)
        @(negedge clk);
        valid_in = 1; sub = 0;
        A = 32'h3FC0_0000; B = 32'hBFA0_0000;

        // Cycle 4: Overflow Check (Max FP32 + Max FP32 -> Infinity)
        @(negedge clk);
        valid_in = 1; sub = 0;
        A = 32'h7F7F_FFFF; B = 32'h7F7F_FFFF;

        // Cycle 5: Underflow Check (Min Normal Subtraction)
        @(negedge clk);
        valid_in = 1; sub = 1;
        A = 32'h00C0_0000; B = 32'h00A0_0000;

        // Cycle 6: De-assert valid_in
        @(negedge clk);
        valid_in = 0;

        // -------------------------------------------------------------
        // VERIFY CONTINUOUS BACK-TO-BACK OUTPUTS AT STAGE 5
        // -------------------------------------------------------------
        
        // Wait for Result 1 (Pipeline Latency = 5 cycles)
        wait(valid_out); #1;
        if (result === 32'h41B0_0000)
            $display("[PASS] Cycle 5 Output (Result 1): 16.0 + 6.0 = 22.0 (Hex: 0x%08h)", result);
        else begin
            $display("[FAIL] Result 1 Mismatch! Got 0x%08h", result);
            errors = errors + 1;
        end

        // Result 2 arrives on the VERY NEXT clock cycle!
        @(posedge clk); #1;
        if (valid_out && result === 32'h0000_0000 && zero)
            $display("[PASS] Cycle 6 Output (Result 2): 20.0 - 20.0 = 0.0  (Hex: 0x%08h, Zero Flag Z=1)", result);
        else begin
            $display("[FAIL] Result 2 Mismatch! Got 0x%08h (zero=%b)", result, zero);
            errors = errors + 1;
        end

        // Result 3 arrives on the VERY NEXT clock cycle!
        @(posedge clk); #1;
        if (valid_out && result === 32'h3E80_0000)
            $display("[PASS] Cycle 7 Output (Result 3): 1.5 + (-1.25) = 0.25 (Hex: 0x%08h)", result);
        else begin
            $display("[FAIL] Result 3 Mismatch! Got 0x%08h", result);
            errors = errors + 1;
        end

        // Result 4 arrives on the VERY NEXT clock cycle!
        @(posedge clk); #1;
        if (valid_out && overflow)
            $display("[PASS] Cycle 8 Output (Result 4): Overflow Detected! (Hex: 0x%08h, Overflow Flag V=1)", result);
        else begin
            $display("[FAIL] Result 4 Mismatch! Expected Overflow V=1, Got V=%b (Result: 0x%08h)", overflow, result);
            errors = errors + 1;
        end

        // Result 5 arrives on the VERY NEXT clock cycle!
        @(posedge clk); #1;
        if (valid_out && underflow)
            $display("[PASS] Cycle 9 Output (Result 5): Underflow Detected! (Hex: 0x%08h, Underflow Flag U=1)", result);
        else begin
            $display("[FAIL] Result 5 Mismatch! Expected Underflow U=1, Got U=%b (Result: 0x%08h)", underflow, result);
            errors = errors + 1;
        end

        // SUMMARY
        $display("\n====================================================");
        if (errors == 0) $display(" ALL PIPELINED FP32 STREAMING TESTS PASSED!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");

        #20;
        $finish;
    end

endmodule