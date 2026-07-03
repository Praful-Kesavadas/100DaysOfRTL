module bcd_counter(input clk, nreset, start, output reg [3:0] count, output carry_out);
    assign carry_out = (count == 4'd9);
    always @(posedge clk or negedge nreset) begin
        if (!nreset) count <= 4'b0000;
        else if(start) begin
            if(count >= 9) count <= 4'd0;
            else count <= count + 1;
        end
    end
endmodule
