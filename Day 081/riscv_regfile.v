module riscv_regfile (
    input clk,

    input [4:0] rs1, rs2,
    output [31:0] rdata1, rdata2,

    input reg_write,
    input [4:0] rd,
    input [31:0] w_data
);
    reg [31:0] rf [0:31];

    //Initial reset to 0
    integer i;
    initial begin
        for(i=0; i<32; i = i+1) 
            rf[i] = 32'd0;
    end

    //Synchronous Write
    always@(posedge clk) begin
        if(reg_write && (rd != 5'd0))
            rf[rd] <= w_data;
    end 

    //Combinational Read with internal WB forwarding and x0 hardwired to 0
    assign rdata1 = (rs1 == 5'd0) ? 32'd0 :
                    (reg_write && (rd == rs1)) ? w_data : rf[rs1];
    assign rdata2 = (rs2 == 5'd0) ? 32'd0 :
                    (reg_write && (rd == rs2)) ? w_data : rf[rs2];
endmodule