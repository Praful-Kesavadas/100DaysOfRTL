module tb_2_to_1mux();
    reg a,b, sel;
    wire out;

    mux2to1 uut(.a(a), .b(b), .sel(sel), .out(out));

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
    end

    initial begin
        sel = 0; a = 1; b = 0;
        #10 sel = 1;
        #10 $finish;
    end
endmodule