//A 1:4 Demux

module demux1to4(input [3:0]in, input [1:0] sel, output reg [3:0] out1, out2, out3, out4);
    always@(*)begin
        {out1, out2, out3, out4} = 16'd0;
        case(sel)
            2'b00: out1 = in;
            2'b01: out2 = in;
            2'b10: out3 = in;
            2'b11: out4 = in;
        endcase
    end
endmodule