module bcd_counter2digit(input clk, nreset, start, output [3:0] tens_digit, units_digit, output carry_out);
    wire units_carry, start2;
    assign start2 = start & units_carry;
    bcd_counter c1(.clk(clk), .nreset(nreset), .start(start), .count(units_digit), .carry_out(units_carry));
    bcd_counter c2(.clk(clk), .nreset(nreset), .start(start2), .count(tens_digit), .carry_out(carry_out));
endmodule
