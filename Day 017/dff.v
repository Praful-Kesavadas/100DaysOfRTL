// Active low reset pin

module dff(input clk, input nreset, input d, output reg q);
    always@(posedge clk or negedge nreset) begin
        if(!nreset) q <= 1'd0;
        else q <= d;
    end
endmodule

