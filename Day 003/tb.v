module tb_demux1to4();
    reg [3:0]in;
    reg [1:0]sel;
    wire [3:0] out1, out2, out3, out4;

    demux1to4 uut(.sel(sel), .in(in), .out1(out1), .out2(out2), .out3(out3), .out4(out4));

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
    end
    initial begin
        in = 4'b1010;
        #10 sel = 2'd0;
        #10 sel = 2'd1;
        #10 sel = 2'd2;
        #10 sel = 2'd3;
        #10 $finish;
    end
endmodule