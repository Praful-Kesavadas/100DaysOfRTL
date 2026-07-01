// This module contains both Johnson and Ring counter depending on the counter mode input(counter_mode = 1 for johnson counter)

module circular_counter(input clk, nreset, counter_mode, output reg [3:0] q);
    always@(posedge clk or negedge nreset) begin
        if(!nreset)
            q <= (counter_mode) ? 4'b0000 : 4'b0001;
        else begin
            q <= (counter_mode) ? {q[2:0], ~q[3]} : {q[2:0], q[3]};
        end
    end
endmodule
