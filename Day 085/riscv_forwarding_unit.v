module riscv_forwarding_unit (
    //Operands in execute stage
    input [4:0] id_ex_rs1, id_ex_rs2,

    //EX/MEM Stage
    input [4:0] ex_mem_rd,
    input ex_mem_reg_write,

    //MEM/WB stage
    input [4:0] mem_wb_rd,
    input mem_wb_reg_write,

    //Forwarding MUX outputs
    output reg [1:0] forward_a, forward_b
);
    //Forwarding for operand A
    always@(*) begin
        //Priority for EX/MEM forwarding(most recent instruction)
        if(ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) begin
            forward_a = 2'b10;
        end
        //Next priority for MEM/WB(older instruction, not overwritten by EX/MEM)
        else if(mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) begin
            forward_a = 2'b01;
        end
        //Default: No forwarding
        else begin
            forward_a = 2'b00;
        end
    end

    //Forwarding for B
    always@(*) begin
        //Priority for EX/MEM
        if(ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2)) begin
            forward_b = 2'b10;
        end
        //MEM/WB forwarding
        else if(mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) begin
            forward_b = 2'b01;
        end
        else forward_b = 2'b00;
    end

endmodule