module true_dual_port_sram #(parameter DATA_WIDTH = 8, parameter DEPTH = 16, parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input clk, 

    input write_en_a,
    input [ADDR_WIDTH-1:0] addr_a,
    input [DATA_WIDTH-1:0] data_in_a,
    output reg [DATA_WIDTH-1:0] data_out_a,

    input write_en_b,
    input [ADDR_WIDTH-1:0] addr_b,
    input [DATA_WIDTH-1:0] data_in_b,
    output reg [DATA_WIDTH-1:0] data_out_b
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always@(posedge clk) begin
        if(write_en_a) begin
            mem[addr_a] <= data_in_a;
        end
        data_out_a <= mem[addr_a];
    end 

    always@(posedge clk) begin
        if(write_en_b) begin
            mem[addr_b] <= data_in_b;
        end
        data_out_b <= mem[addr_b];
    end
endmodule
