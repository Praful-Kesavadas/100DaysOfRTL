//4 bit ripple carry adder using the full adder block

module ripple_adder(input [3:0] a, b, input carry_in, output [3:0] sum, output carry_out);
    wire [3:0] carry;
    full_adder fa1(.a(a[0]), .b(b[0]), .carry_in(carry_in), .sum(sum[0]), .carry_out(carry[0]));
    full_adder fa2(.a(a[1]), .b(b[1]), .carry_in(carry[0]), .sum(sum[1]), .carry_out(carry[1]));
    full_adder fa3(.a(a[2]), .b(b[2]), .carry_in(carry[1]), .sum(sum[2]), .carry_out(carry[2]));
    full_adder fa4(.a(a[3]), .b(b[3]), .carry_in(carry[2]), .sum(sum[3]), .carry_out(carry[3]));
    assign carry_out = carry[3];
endmodule
