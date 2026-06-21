module bcd_adder(input [3:0] a, b, input carry_in, output [3:0] sum, output carry_out);
    wire [3:0] sum1;
    wire carry1, carry2;
    wire add_second_stage;

    assign add_second_stage = carry1 | sum1[3] & sum1[2] | sum1[3] & sum1[1];
    
    ripple_adder ra1(.a(a), .b(b), .carry_in(carry_in), .sum(sum1), .carry_out(carry1));
    ripple_adder ra2(.a({1'b0, {2{add_second_stage}}, 1'b0}), .b(sum1), .carry_in(1'b0), .sum(sum), .carry_out(carry2));

    assign carry_out = add_second_stage;
endmodule
