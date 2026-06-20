`timescale 1ns / 1ps

module tb_cla_4bit;

    // Testbench registers and wires
    reg [3:0] a, b;
    reg carry_in;

    wire [3:0] sum;
    wire carry_out;

    cla_4bit uut (
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .sum(sum),
        .carry_out(carry_out)
    );

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
        $monitor("Time = %0d ns | Inputs: A = %b (%2d) B = %b (%2d) Carry_in = %b | Outputs: Sum = %b (%2d) Carry_out = %b", 
                 $time, a, a, b, b, carry_in, sum, sum, carry_out);
    end

    initial begin
        a = 4'b0000; b = 4'b0000; carry_in = 1'b0;
        #10;
        
        // Test Case 1: Standard Addition (No Carries)
        a = 4'd4; b = 4'd5; carry_in = 1'b0;      // 4 + 5 = 9 (Sum=1001, carry_out=0)
        #10;
        
        // Test Case 2: Addition with active Carry In
        a = 4'd3; b = 4'd4; carry_in = 1'b1;      // 3 + 4 + 1 = 8 (Sum=1000, carry_out=0)
        #10;
        
        // Test Case 3: The Full Lookahead Chain Test
        // Forces all propagates high (P=1111) to evaluate the longest SOP path instantly
        a = 4'b1111; b = 4'b0000; carry_in = 1'b1; // 15 + 0 + 1 = 16 (Sum=0000, carry_out=1)
        #10;
        
        // Test Case 4: Max Saturation Boundary
        a = 4'b1111; b = 4'b1111; carry_in = 1'b1; // 15 + 15 + 1 = 31 (Sum=1111, carry_out=1)
        #10;
        
        // Return to Idle
        a = 4'b0000; b = 4'b0000; carry_in = 1'b0;
        #10;

        $finish;
    end

endmodule