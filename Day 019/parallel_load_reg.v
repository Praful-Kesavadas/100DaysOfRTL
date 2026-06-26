module parallel_load_reg(input clk, nreset, load, input [3:0] data_in, output reg [3:0] q);
    always@(posedge clk or negedge nreset) begin
        if(!nreset) q <= 4'd0;
        else begin
            q <= (load) ? data_in : q;
        end
    end
endmodule
