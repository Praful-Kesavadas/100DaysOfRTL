module cla_4bit(input [3:0] a, b, input carry_in, output [3:0] sum, output carry_out);
    wire [3:0] g, p; //g_i and p_i are the i th stage carry_generate and carry_propagate
    wire [3:1] c; //Intermediate carries

    assign g = a & b;
    assign p = a ^ b;
    assign c[1] = g[0] | p[0] & carry_in;
    assign c[2] = g[1] | p[1] & g[0] | p[1] & p[0] & carry_in;
    assign c[3] = g[2] | p[2] & g[1] | p[2] & p[1] & g[0] | p[2] & p[1] & p[0] & carry_in;
    assign carry_out = g[3] | p[3] & g[2] | p[3] & p[2] & g[1] | p[3] & p[2] & p[1] & g[0] | &(p) & carry_in; 
    assign sum = p ^ {c, carry_in};

endmodule
