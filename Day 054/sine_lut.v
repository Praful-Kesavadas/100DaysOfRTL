module sine_lut#(parameter DATA_WIDTH = 8, parameter DEPTH = 16, parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input clk, 
    input [ADDR_WIDTH-1:0] addr,
    output reg [DATA_WIDTH-1:0] sine_val
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    initial begin
        $readmemh("sine_table.hex", mem);
    end
    always@(posedge clk) begin
        sine_val <= mem[addr];
    end
endmodule
