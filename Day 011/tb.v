`timescale 1ns / 1ps

module tb_adder_sub4bit;

    reg [3:0] a, b;
    reg subtract;

    wire [3:0] result;
    wire add_carry_out, sub_borrow_out;
    wire [23:0] mode;

    adder_sub4bit uut (
        .a(a),
        .b(b),
        .subtract(subtract),
        .result(result),
        .add_carry_out(add_carry_out),
        .sub_borrow_out(sub_borrow_out)
    );

    assign mode = subtract ? "SUB" : "ADD";
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
        $monitor("Time = %0d ns | Mode = %s | A = %2d B = %2d | Result = %2d (Binary = %b) | Add_Cout = %b Sub_Bout = %b", 
                 $time, mode, a, b, result, result, add_carry_out, sub_borrow_out);
    end

    initial begin
        a = 4'd0; b = 4'd0; subtract = 1'b0;
        #10;
        
        // MODE 0: ADDITION (subtract = 0)
        
        // Case 1: Standard Addition (No Overflow)
        a = 4'd5;  b = 4'd3;  #10; // 5 + 3 = 8  (Result=1000, Add_Cout=0, Sub_Bout=0)
        
        // Case 2: Max Limit Addition (No Overflow)
        a = 4'd10; b = 4'd5;  #10; // 10 + 5 = 15 (Result=1111, Add_Cout=0, Sub_Bout=0)
        
        // Case 3: Addition with Out-of-Bounds Overflow
        a = 4'd13; b = 4'd5;  #10; // 13 + 5 = 18 => 2 (Result=0010, Add_Cout=1, Sub_Bout=0)


        // MODE 1: SUBTRACTION (subtract = 1)
        subtract = 1'b1;
        #10;
        
        // Case 4: Standard Subtraction (Positive Result)
        a = 4'd10; b = 4'd4;  #10; // 10 - 4 = 6  (Result=0110, Add_Cout=0, Sub_Bout=0)
        
        // Case 5: Zero Boundary Subtraction
        a = 4'd7;  b = 4'd7;  #10; // 7 - 7 = 0   (Result=0000, Add_Cout=0, Sub_Bout=0)
        
        // Case 6: Subtraction with Underflow (Negative Result)
        a = 4'd3;  b = 4'd8;  #10; // 3 - 8 = -5 => 11 (Result=1011, Add_Cout=0, Sub_Bout=1)


        // --- Return to Idle State ---
        subtract = 1'b0; a = 4'd0; b = 4'd0; #10;
        
        $finish;
    end

endmodule