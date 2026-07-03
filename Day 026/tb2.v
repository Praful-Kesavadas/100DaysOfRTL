`timescale 1ns / 1ps

module tb_bcd_counter_2digit;

    reg clk;
    reg nreset;
    reg start;
    wire [3:0] tens_digit;
    wire [3:0] units_digit;
    wire carry_out;

    bcd_counter2digit uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .tens_digit(tens_digit),
        .units_digit(units_digit),
        .carry_out(carry_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("bcd_2digit.vcd");
        $dumpvars(0);

        // --- Clear array to 00 ---
        nreset = 1'b0; start = 1'b0; #12;
        nreset = 1'b1; #10;
        
        // --- Let it run for 25 clock edges ---
        // This easily clears the 09->10 boundary and the 19->20 boundary
        start = 1'b1;
        #250;
        
        start = 1'b0; #10;
        $finish;
    end

endmodule