module processor_file_array#(parameter DATA_WIDTH = 32, parameter DEPTH = 32, parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input clk,
    //Read 
    input [ADDR_WIDTH-1:0] rs1_addr_in, rs2_addr_in,
    output [DATA_WIDTH-1:0] rs1_data_out, rs2_data_out,

    //Write
    input write_en,
    input [ADDR_WIDTH-1:0] wr_addr,
    input [DATA_WIDTH-1:0] wr_data
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    //Write logic(Inhibits the write to address x0)
    always@(posedge clk) begin
        if(write_en && (wr_addr != {ADDR_WIDTH{1'b0}})) begin
            mem[wr_addr] <= wr_data;
        end
    end

    //Read Logic
    /*Priority order:
        1. Address 0 check -> Always force 0 (x0 hardwire)
        2. RAW Hazard check -> Forward wr_data immediately if writing to same address
        3. Normal Read -> Output register array content
    */
    assign rs1_data_out = (rs1_addr_in == {ADDR_WIDTH{1'b0}}) ? {DATA_WIDTH{1'b0}} :
                          (write_en && (wr_addr == rs1_addr_in)) ? wr_data :
                          mem[rs1_addr_in];
    assign rs2_data_out = (rs2_addr_in == {ADDR_WIDTH{1'b0}}) ? {DATA_WIDTH{1'b0}} :
                          (write_en && (wr_addr == rs2_addr_in)) ? wr_data :
                          mem[rs2_addr_in];
endmodule