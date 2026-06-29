module tff(input T, clk, nreset, output reg q, output q_bar);
    assign q_bar = ~q;
    always@(posedge clk or negedge nreset) begin
        if(!nreset) q <= 1'b0;
        else q <= T ? (~q) : q;
    end
endmodule
