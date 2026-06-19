module mag_comp(input [3:0]a, b, output a_greater_than_b, a_equal_b, a_less_than_b);
    wire [3:0] equalities;

    assign equalities = a ~^ b;
    assign a_greater_than_b = a[3] & ~(b[3]) |
                              equalities[3] & a[2] & ~(b[2]) |
                              equalities[3] & equalities[2] & a[1] & ~(b[1]) |
                              equalities[3] & equalities[2] & equalities[1] & a[0] & ~(b[0]);
    assign a_equal_b = &(equalities);
    assign a_less_than_b = ~(a_equal_b | a_greater_than_b);
endmodule
