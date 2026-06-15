//Making a full adder by using 2 half adders

module full_adder(input a, b, carry_in, output sum, carry_out);
    wire sum1, carry1, carry2;
    half_adder ha1(.a(a), .b(b), .sum(sum1), .carry(carry1));
    half_adder ha2(.a(carry_in), .b(sum1), .sum(sum), .carry(carry2));

    assign carry_out = carry1 | carry2;
endmodule
