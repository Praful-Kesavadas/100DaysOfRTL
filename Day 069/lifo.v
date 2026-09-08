module lifo_stack#(
    parameter DATA_WIDTH = 16,
    parameter DEPTH = 8,
    parameter PTR_WIDTH = $clog2(DEPTH)
)(
    input clk, nreset, 
    input push, pop, 
    input [DATA_WIDTH-1:0] d_in,
    output reg [DATA_WIDTH-1:0] d_out,
    output empty, full,
    output reg overflow, underflow
);

    reg [DATA_WIDTH-1:0] stack_mem [0:DEPTH-1];
    reg [PTR_WIDTH-1:0] SP; //Points to next write location
    reg [PTR_WIDTH:0] count; // Occupancy counter

    //Status Flags
    assign full = (count == DEPTH);
    assign empty = (count == 0);

    integer i;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            SP <= 0;
            count <= 0;
            overflow <= 0;
            underflow <= 0;
            d_out <= 0;
            for(i = 0; i < DEPTH; i = i + 1) begin
                stack_mem[i] <= {DATA_WIDTH{1'b0}};
            end
        end
        else begin
            overflow <= 0;
            underflow <= 0;

            case({push, pop})
                2'b10: begin
                    if(!full) begin
                        stack_mem[SP] <= d_in;
                        SP <= SP + 1'b1;
                        count <= count + 1'b1;
                    end
                    else overflow <= 1'b1;
                end
                2'b01: begin
                    if(!empty) begin
                        d_out <= stack_mem[SP-1'b1];
                        SP <= SP - 1'b1;
                        count <= count - 1'b1;
                    end
                    else underflow <= 1'b1;
                end
                2'b11: begin
                    if(full) begin  // If full, pop the data and write new data to top of stack(count and SP unchanged)
                        d_out <= stack_mem[SP - 1'b1];
                        stack_mem[SP - 1'b1] <= d_in;
                    end
                    else if(empty) begin    // If empty reject the pop and push data
                        underflow <= 1'b1;
                        stack_mem[SP] <= d_in;
                        SP <= SP + 1'b1;
                        count <= count + 1'b1;
                    end
                    else begin  // Otherwise, pop the current data and push new data into same spot
                        d_out <= stack_mem[SP-1'b1];
                        stack_mem[SP-1'b1] <= d_in;
                    end
                end
                default: begin//No operation(Hold)
                end
            endcase
        end
    end
endmodule