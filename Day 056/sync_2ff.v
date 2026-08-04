module sync_2ff#(parameter DATA_WIDTH = 8
)(
    input clk, nreset,
    input [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out
);
    //Forces synthesis engine to place both FFs adjacent on silicon
    (* ASYNC_REG = "TRUE" *) reg [DATA_WIDTH-1:0] sync_stage1;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            sync_stage1 <= 0;
            data_out <= 0;
        end
        else begin
            sync_stage1 <= data_in;
            data_out <= sync_stage1;
        end
    end 
endmodule
