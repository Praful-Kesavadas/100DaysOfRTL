module asyn_fifo #(
    parameter DEPTH = 16,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    //Write Domain
    input wr_clk,
    input wr_rst_n,
    input wr_en,
    input [DATA_WIDTH-1:0] data_in,
    output full,

    //Read Domain
    input rd_clk,
    input rd_rst_n,
    input rd_en,
    output reg [DATA_WIDTH-1:0] data_out,
    output empty
);

    //Pointers for both domains
    reg [ADDR_WIDTH:0] wr_ptr_bin;
    wire [ADDR_WIDTH:0] wr_ptr_gray;
    reg [ADDR_WIDTH:0] rd_ptr_bin;
    wire [ADDR_WIDTH:0] rd_ptr_gray;

    assign wr_ptr_gray = wr_ptr_bin ^ (wr_ptr_bin >> 1);
    assign rd_ptr_gray = rd_ptr_bin ^ (rd_ptr_bin >> 1);

    //Synchronizer for write pointer(from write domain to read domain)
    wire [ADDR_WIDTH:0] wr_ptr_gray_rd_domain;
    sync_2ff #(.DATA_WIDTH(ADDR_WIDTH+1)) sync_wr2rd(.clk(rd_clk), .nreset(rd_rst_n), .data_in(wr_ptr_gray), .data_out(wr_ptr_gray_rd_domain));

    //Synchronizer for read pointer(from read domain to write domain)
    wire [ADDR_WIDTH:0] rd_ptr_gray_wr_domain;
    sync_2ff #(.DATA_WIDTH(ADDR_WIDTH+1)) sync_rd2wr(.clk(wr_clk), .nreset(wr_rst_n), .data_in(rd_ptr_gray), .data_out(rd_ptr_gray_wr_domain));

    //Memory Array
    reg [DATA_WIDTH-1:0] mem[0:DEPTH-1];

    //Write operation
    wire wr_valid = wr_en && !full;
    always@(posedge wr_clk) begin
        if(wr_valid) mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= data_in;
    end

    //Write Pointer Advancement
    always@(posedge wr_clk or negedge wr_rst_n) begin
        if(!wr_rst_n) wr_ptr_bin <= 0;
        else if(wr_valid) wr_ptr_bin <= wr_ptr_bin + 1'b1;
    end

    //Full condition: Two MSBs 0 and rest 1(In binary, only MSB will be inverted, but in gray code 2 MSBs will be inverted)
    assign full = (wr_ptr_gray == {~rd_ptr_gray_wr_domain[ADDR_WIDTH:ADDR_WIDTH-1], rd_ptr_gray_wr_domain[ADDR_WIDTH-2:0]});

    //Read Domain
    wire rd_valid = rd_en && !empty;
    always@(posedge rd_clk or negedge rd_rst_n) begin
        if(!rd_rst_n) begin
            rd_ptr_bin <= 0;
            data_out <= 0;
        end
        else if(rd_valid) begin
            data_out <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
            rd_ptr_bin <= rd_ptr_bin + 1'b1;
        end
    end 

    assign empty = (rd_ptr_gray == wr_ptr_gray_rd_domain);
endmodule
