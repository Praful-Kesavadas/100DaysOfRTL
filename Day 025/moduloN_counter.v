//The counter will count from 0 to MAX_COUNT - 1, i.e. modulo-10 counts from 0 to 9

module moduloN_counter #(parameter WIDTH = 5, parameter MAX_COUNT = 31)(
    input clk, nreset, start, output reg [WIDTH-1:0] count, output max_count
);
    assign max_count = (count == (MAX_COUNT -1));
    always @(posedge clk or negedge nreset) begin
        if (!nreset) count <= {WIDTH{1'b0}};
        else if (start) begin
            if(count == MAX_COUNT - 1) count <= {WIDTH{1'b0}};
            else count <= count + 1;
        end
    end
endmodule
