module jkff(input j, k, clk, nreset, output reg q, output q_bar);
    assign q_bar = ~q;
    always@(posedge clk or negedge nreset) begin
        if(!nreset) q <= 1'b0;
        else begin
            case({j,k})
                2'b00: q <= q;
                2'b01: q <= 1'b0;
                2'b10: q <= 1'b1;
                2'b11: q <= ~q;
                default: q <= q;
            endcase
        end
    end
endmodule
