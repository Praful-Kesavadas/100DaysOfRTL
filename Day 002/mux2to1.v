//A 2:1 mux using conditional operator

module mux2to1(input sel, a, b, output out);
    assign out = (sel)? a: b;
endmodule