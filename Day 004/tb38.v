module tb_decoder3to8();
    reg en;
    reg [2:0] sel;
    wire [7:0] out;

    decoder3to8 uut(.sel(sel), .en(en), .out(out));

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
    end

    initial begin
        en =0;
        #10 en =1; 
        #10 sel = 3'd0;
        #10 sel = 3'd1;
        #10 sel = 3'd2;
        #10 sel = 3'd3;
        #10 sel = 3'd4;
        #10 sel = 3'd5;
        #10 sel = 3'd6;
        #10 sel = 3'd7;
        #10 $finish; 
    end
endmodule