`timescale 1ns / 1ps

module tb_binary_sub4bit;

    reg [3:0] a, b;
    wire [3:0] difference;
    wire borrow_out;

    binary_sub4bit uut (.a(a), .b(b), .difference(difference), .borrow_out(borrow_out));

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
        $monitor("Time = %0d ns | Inputs: A = %b (%0d) B = %b (%0d) | Outputs: Diff = %b (%0d) Bout = %b", $time, a, a, b, b, difference, difference, borrow_out);
    end

    initial begin
        a = 4'b0000; b = 4'b0000; #10;
        
        // --- Test Case 1: Standard Positive Result (A > B) ---
        a = 4'd7; b = 4'd3;     // 7 - 3 = 4 (Diff=0100, Bout=0)
        #10;
        
        // --- Test Case 2: Zero Boundary Condition (A = B) ---
        a = 4'd5; b = 4'd5;     // 5 - 5 = 0 (Diff=0000, Bout=0)
        #10;
        
        // --- Test Case 3: Underflow / Negative Result (A < B) ---
        // Expect borrow_out to drive high (1) and Diff to show the 2's complement of -4
        a = 4'd2; b = 4'd6;     // 2 - 6 = -4 => 16 - 4 = 12 (Diff=1100, Bout=1)
        #10;

        // --- Test Case 4: Maximum Value Positive Boundary ---
        a = 4'd15; b = 4'd0;    // 15 - 0 = 15 (Diff=1111, Bout=0)
        #10;
        
        // --- Test Case 5: Maximum Value Underflow Boundary ---
        a = 4'd0; b = 4'd15;    // 0 - 15 = -15 => 16 - 15 = 1 (Diff=0001, Bout=1)
        #10;
        
        // Return to idle state
        a = 4'b0000; b = 4'b0000;
        #10;

        $finish;
    end

endmodule