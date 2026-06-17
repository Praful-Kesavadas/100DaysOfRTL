`timescale 1ns / 1ps

module tb_cascade_sub4bit;

    reg [3:0] a, b;
    reg borrow_in;
    
    wire [3:0] difference;
    wire borrow_out;

    cascade_sub4bit uut (
        .a(a),
        .b(b),
        .borrow_in(borrow_in),
        .difference(difference),
        .borrow_out(borrow_out)
    );

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
        $monitor("Time = %0d ns | Inputs: A = %d B = %d Bin = %b | Outputs: Diff = %d Bout = %b (Diff_Bin = %b)", 
                 $time, a, b, borrow_in, difference, borrow_out, difference);
    end

    initial begin
        a = 4'd0; b = 4'd0; borrow_in = 1'b0; #10;
        
        // --- Test Case 1: Standard Positive Subtraction (Bin = 0) ---
        a = 4'd10; b = 4'd4; borrow_in = 1'b0;      // 10 - 4 - 0 = 6 (Diff=0110, Bout=0)
        #10;
        
        // --- Test Case 2: Same Parameters with Active Input Borrow (Bin = 1) ---
        // This proves that an incoming borrow correctly decrements the overall result
        a = 4'd10; b = 4'd4; borrow_in = 1'b1;      // 10 - 4 - 1 = 5 (Diff=0101, Bout=0)
        #10;
        
        // --- Test Case 3: Zero Boundary Condition via Active Borrow ---
        a = 4'd5; b = 4'd4; borrow_in = 1'b1;       // 5 - 4 - 1 = 0 (Diff=0000, Bout=0)
        #10;

        // --- Test Case 4: Underflow Generation (Bin = 0) ---
        a = 4'd3; b = 4'd7; borrow_in = 1'b0;       // 3 - 7 - 0 = -4 => 16 - 4 = 12 (Diff=1100, Bout=1)
        #10;
        
        // --- Test Case 5: Underflow Generation with Active Borrow (Bin = 1) ---
        a = 4'd3; b = 4'd7; borrow_in = 1'b1;       // 3 - 7 - 1 = -5 => 16 - 5 = 11 (Diff=1011, Bout=1)
        #10;
        
        a = 4'd0; b = 4'd0; borrow_in = 1'b0;
        #10;

        $finish;
    end

endmodule