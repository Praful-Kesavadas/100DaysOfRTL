module adder_sub4bit(input [3:0] a, b, input subtract, output [3:0] result, output add_carry_out, sub_borrow_out);
    wire [3:0] b_xor;
    wire carry_out;

    assign b_xor = b ^ {4{subtract}};

    ripple_adder ra(.a(a), .b(b_xor), .carry_in(subtract), .sum(result), .carry_out(carry_out));

    assign add_carry_out = ~subtract & carry_out;
    assign sub_borrow_out = subtract & ~carry_out;
endmodule
