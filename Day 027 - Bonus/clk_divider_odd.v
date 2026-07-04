module clk_divider_odd #(parameter DIVIDE_BY = 3)(input clk_in, nreset, start, output clk_out);
    localparam WIDTH = $clog2(DIVIDE_BY);
    reg [WIDTH-1:0] count_pos;
    reg clk_pos, clk_neg;
    
    // Makes sure that the clk_pos is active only till the integer cycles till the DIVIDE_BY/2. For example, 5 cycles -> Only till 2 cycles. But still
    // we need 0.5 cycle more, this is obtained by shifting the clk_pos by 0.5 cycles -> can be done using another clk_neg which copies the value of clk_pos
    // but with a 0.5 cycle delay. Done through a negative edge triggered flipflop
    always @(posedge clk_in or negedge nreset) begin
        if (!nreset) begin
            count_pos <= {WIDTH{1'b0}};
            clk_pos <= 1'b0;
        end
        else if(start) begin
            if(count_pos >= DIVIDE_BY-1) count_pos <= {WIDTH{1'b0}};
            else begin 
                count_pos <= count_pos + 1;
            end
            clk_pos <= (count_pos < (DIVIDE_BY/2));
        end
        else clk_pos <= 1'b0;
    end
    // For introducing a 0.5 cycle delay
    always @(negedge clk_in or negedge nreset) begin
        if(!nreset) begin
            clk_neg <= 1'b0;
        end
        else if(start) begin
            clk_neg <= clk_pos;
        end
        else begin 
            clk_neg <= 1'b0;
        end
    end
    assign clk_out = clk_pos | clk_neg;
endmodule
