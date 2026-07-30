module dual_port_sram #(parameter DATA_WIDTH = 8, parameter DEPTH = 8, parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input clk, 
    input write_en, read_en,
    input [DATA_WIDTH-1:0] data_in,
    input [ADDR_WIDTH-1:0] addr_read, addr_write,
    output reg [DATA_WIDTH-1:0] data_out
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    always@(posedge clk) begin
        if(write_en) begin
            mem[addr_write] <= data_in;
        end
    end 
    always@(posedge clk) begin
        if(read_en) begin
            data_out <= mem[addr_read];
        end
    end
endmodule
