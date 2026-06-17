//This is a cascade-friendly subtractor module(accepts input borrow bit)

module cascade_sub4bit(input [3:0] a, b, input borrow_in, output [3:0] difference, output borrow_out);
    wire [3:0] b_inv;
    wire carry_out;

    assign b_inv = ~b;
    ripple_adder ra(.a(a), .b(b_inv), .carry_in(~borrow_in), .sum(difference), .carry_out(carry_out));

    assign borrow_out = ~carry_out;
endmodule
