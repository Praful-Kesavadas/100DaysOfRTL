`timescale 1ns / 1ps

module tb_ripple_adder();

    reg [3:0] a, b;
    reg carry_in;
    wire [3:0] sum;
    wire carry_out;

    ripple_adder uut (
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .sum(sum),
        .carry_out(carry_out)
    );

    initial begin
        $monitor("Time= %0d ns | Inputs: A = %b (%0d) B = %b (%0d) Cin = %b | Outputs: Sum = %b (%0d) Cout = %b", 
                 $time, a, a, b, b, carry_in, sum, sum, carry_out);
    end
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
    end
    initial begin
        a = 4'b0000; b = 4'b0000; carry_in = 1'b0;
        #10; 
        
        // --- Test Case 1: Standard Addition (No Carries Generated) ---
        a = 4'b0010; b = 4'b0101; carry_in = 1'b0;   // 2 + 5 = 7 (Sum=0111, Cout=0)
        #10;
        
        // --- Test Case 2: Addition with Carry In Active ---
        a = 4'b0011; b = 4'b0100; carry_in = 1'b1;   // 3 + 4 + 1 = 8 (Sum=1000, Cout=0)
        #10;
        
        // --- Test Case 3: Mid-vector Overflow Generation ---
        a = 4'b1100; b = 4'b0100; carry_in = 1'b0;   // 12 + 4 = 16 (Sum=0000, Cout=1)
        #10;

        // --- Test Case 4: The Full Ripple Test (Critical Corner Case) ---
        // This forces the carry bit to sequentially travel through every single stage 
        // from the LSB full adder to the final MSB full adder.
        a = 4'b1111; b = 4'b0001; carry_in = 1'b0;   // 15 + 1 = 16 (Sum=0000, Cout=1)
        #10;
        
        // --- Test Case 5: Maximum Saturation Capacity ---
        // Satures every bit of the adder grid to check maximum limit limits.
        a = 4'b1111; b = 4'b1111; carry_in = 1'b1;   // 15 + 15 + 1 = 31 (Sum=1111, Cout=1)
        #10;
        
        // Return back to idle/zero state
        a = 4'b0000; b = 4'b0000; carry_in = 1'b0;
        #10;
        $finish;
    end

endmodule