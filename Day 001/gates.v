//Using in built gates and verifying the output

module logic_gates(input a, b, output wire out_and, out_or, out_nor, out_xor, out_xnor, out_nand);
    and(out_and, a, b);
    nand(out_nand, a, b);
    or(out_or, a, b);
    nor(out_nor, a, b);
    xor(out_xor, a, b);
    xnor(out_xnor, a, b);
endmodule
