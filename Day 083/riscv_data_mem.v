module riscv_data_mem #(
    parameter MEM_DEPTH = 1024
)(
    input clk, en,
    input [3:0] wstrb, 
    input [31:0] addr, wdata,
    output [31:0] rdata
);
    reg [31:0] mem[0:MEM_DEPTH-1];

    localparam ADDR_WIDTH = $clog2(MEM_DEPTH);
    wire [ADDR_WIDTH-1:0] word_idx = addr[ADDR_WIDTH+1:2];

    always@(posedge clk) begin
        if(en) begin
            if(wstrb[0]) mem[word_idx][7:0] <= wdata[7:0];
            if(wstrb[1]) mem[word_idx][15:8] <= wdata[15:8];
            if(wstrb[2]) mem[word_idx][23:16] <= wdata[23:16];
            if(wstrb[3]) mem[word_idx][31:24] <= wdata[31:24];
        end
    end

    assign rdata = en ? mem[word_idx] : 32'd0;
endmodule