// The input clock frequency is brought down to by a multiple of 2, which is input as a parameter
module clk_divider_even #(parameter DIVIDE_BY = 4)(input clk_in, nreset, start, output reg clk_out);
    localparam MIDPOINT = (DIVIDE_BY/2) - 1;
    localparam WIDTH = $clog2(MIDPOINT + 1);
    reg [WIDTH-1:0] count;
    always @(posedge clk_in or negedge nreset)begin
        if(!nreset) begin
            count <= {WIDTH{1'b0}};
            clk_out <= 1'b0;
        end
        else if(start) begin
            if(count >= MIDPOINT) begin
                count <= {WIDTH{1'b0}};
                clk_out <= ~clk_out; 
            end
            else count <= count + 1;
        end
    end
endmodule
