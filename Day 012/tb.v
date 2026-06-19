`timescale 1ns / 1ps

module tb_mag_comp;

    reg [3:0] a, b;

    wire a_greater_than_b, a_equal_b, a_less_than_b;

    mag_comp uut (
        .a(a),
        .b(b),
        .a_greater_than_b(a_greater_than_b),
        .a_equal_b(a_equal_b),
        .a_less_than_b(a_less_than_b)
    );

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
        $monitor("Time = %0d ns | A = %4b (%d) B = %4b (%d) | GT = %b EQ = %b LT = %b", 
                 $time, a, a, b, b, a_greater_than_b, a_equal_b, a_less_than_b);
    end

    initial begin
        // Case 1: Initial Equality at Zero
        a = 4'd0; b = 4'd0; #10;
        
        // Case 2: Greater Than Condition (MSB difference dominates)
        a = 4'd12; b = 4'd4; #10; // 12 > 4 -> GT=1, EQ=0, LT=0
        
        // Case 3: Less Than Condition
        a = 4'd3; b = 4'd9; #10;  // 3 < 9  -> GT=0, EQ=0, LT=1
        
        // Case 4: Equal Condition at Saturation Maximum
        a = 4'd15; b = 4'd15; #10; // 15==15 -> GT=0, EQ=1, LT=0
        
        // Case 5: Greater Than Condition settled by LSB bit boundaries
        a = 4'd7; b = 4'd6; #10;  // 7 > 6  -> GT=1, EQ=0, LT=0
        
        $finish;
    end

endmodule