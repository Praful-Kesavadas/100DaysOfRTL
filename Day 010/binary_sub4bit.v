module binary_sub4bit(input [3:0] a, b, output [3:0] difference, output borrow_out);
    
    wire [3:0] b_inv;
    wire carry_out;
    assign b_inv = ~b;

    rippleAdder ra(.a(a), .b(b_inv), .carry_in(1'b1), .sum(difference), .carry_out(carry_out));

    assign borrow_out = ~carry_out;

endmodule