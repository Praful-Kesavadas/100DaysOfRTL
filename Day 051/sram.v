module sram#(parameter DATA_WIDTH = 8, parameter DEPTH = 16, parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input clk,
    input chip_enable,
    input write_enable, //1 -> write, 0 -> read
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] out
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    always@(posedge clk) begin
        if(chip_enable) begin
            if(write_enable) begin
                mem[addr] <= data_in;
            end
            out <= mem[addr];
        end
    end
endmodule
