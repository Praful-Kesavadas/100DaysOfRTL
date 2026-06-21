`timescale 1ns / 1ps

module tb_bcd_adder;

    reg [3:0] a, b;
    reg carry_in;

    wire [3:0] sum;
    wire carry_out;
    wire [4:0] bcd_hex;

    bcd_adder uut (
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .sum(sum),
        .carry_out(carry_out)
    );

    assign bcd_hex = a + b + carry_in;
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
        $monitor("Time = %0d ns | Inputs: A = %d B = %d Cin = %b | Outputs: BCD_Sum = %d BCD_Cout = %b (Raw hex sum = %X)", 
                 $time, a, b, carry_in, sum, carry_out, bcd_hex);
    end

    initial begin
        a = 4'd0; b = 4'd0; carry_in = 1'b0;
        #10;
        
        // --- Test Case 1: Standard Valid Addition (Result <= 9) ---
        // Expect no correction cycle. sum1 should match sum directly.
        a = 4'd4; b = 4'd3; carry_in = 1'b0;      // 4 + 3 = 7  (BCD_Sum=0111, BCD_Cout=0)
        #10;
        
        // --- Test Case 2: In-Bounds Detection Threshold (10 <= Result <= 15) ---
        // Checks lookahead logic (sum1[3] & sum1[2] | sum1[3] & sum1[1])
        a = 4'd6; b = 4'd7; carry_in = 1'b0;      // 6 + 7 = 13 (>9) -> +6 Correction -> (BCD_Sum=0011 (3), BCD_Cout=1)
        #10;
        
        // --- Test Case 3: Binary Overflow Boundary Trigger (Result >= 16) ---
        // Checks lookahead detection via first stage carry1 assertion
        a = 4'd9; b = 4'd8; carry_in = 1'b0;      // 9 + 8 = 17 (>15) -> +6 Correction -> (BCD_Sum=0111 (7), BCD_Cout=1)
        #10;

        // --- Test Case 4: Zero Boundary Sweep ---
        a = 4'd5; b = 4'd5; carry_in = 1'b0;      // 5 + 5 = 10 (>9) -> +6 Correction -> (BCD_Sum=0000 (0), BCD_Cout=1)
        #10;
        
        // --- Test Case 5: Maximum Corner Saturation with Carry In ---
        a = 4'd9; b = 4'd9; carry_in = 1'b1;      // 9 + 9 + 1 = 19 -> +6 Correction -> (BCD_Sum=1001 (9), BCD_Cout=1)
        #10;
        
        // --- Return to Idle State ---
        a = 4'd0; b = 4'd0; carry_in = 1'b0;
        #10;

        $finish;
    end

endmodule