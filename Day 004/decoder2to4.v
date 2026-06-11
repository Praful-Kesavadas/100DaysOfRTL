//Designing a 2 to 4

module decoder2to4(input [1:0]sel, input en, output reg [3:0]out);
    always @(*) begin
        out = 4'b0000;
        if(en) begin
            case(sel)
                2'b00: out[0] = 1;
                2'b01: out[1] = 1;
                2'b10: out[2] = 1;
                2'b11: out[3] = 1;
            endcase
        end
    end
endmodule
