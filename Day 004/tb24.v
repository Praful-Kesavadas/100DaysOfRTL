module tb_decoder2to4();
    reg [1:0] sel;
    reg en;
    wire [3:0] out;

    decoder2to4 uut(.sel(sel), .en(en), .out(out));

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
    end

    initial begin
        en =0;
        #10 en =1; 
        #10 sel = 2'b00;
        #10 sel = 2'b01;
        #10 sel = 2'b10;
        #10 sel = 2'b11;
        #10 $finish; 
    end
endmodule