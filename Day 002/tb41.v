module tb_mux4to1();
    reg [3:0] a,b,c,d;
    reg [1:0] sel;
    wire [3:0] out;

    mux4to1 uut(.a(a), .b(b), .c(c), .d(d), .sel(sel), .out(out));

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
    end
    initial begin
        a = 4'b0001; b = 4'b0010; c = 4'b0100; d = 4'b1000;
        #10 sel = 2'd0;
        #10 sel = 2'd1;
        #10 sel = 2'd2;
        #10 sel = 2'd3;
        #10 $finish;
    end
endmodule