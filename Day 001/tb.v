module tb_logic_gates();
    reg a, b;
    wire out_and, our_xor, out_nor, out_or, out_xnor, out_nand;

    logic_gates uut(.a(a), .b(b), .out_and(out_and), .out_nor(out_nor), .out_xor(out_xor), .out_or(out_or), .out_xnor(out_xnor), .out_nand(out_nand));

    initial begin
        a = 0; b = 0;
        #10
        b = 1;
        #10 a = 1; b = 0;
        #10 b = 1;
        #10 $finish;
    end 
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
    end
endmodule