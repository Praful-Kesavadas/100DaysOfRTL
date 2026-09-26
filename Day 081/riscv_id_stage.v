module riscv_id_stage (
    input clk, nreset,

    input stall_ex, // 1 = Hold ID/EX stage
    input flush_ex, // 1 = Clear ID/EX register to NOP bubble

    //Inputs from IF/ID reg
    input [31:0] if_id_pc, if_id_pc_plus_4,
    input [31:0] if_id_instr,

    ///Inputs from WB stage(Register file write port)
    input wb_reg_write,
    input [4:0] wb_rd,
    input [31:0] wb_wdata,

    //Raw decoded fields to hazard detection unit
    output [4:0] id_rs1, id_rs2,
    output id_rs1_valid, id_rs2_valid, //Hazard Check validity(If 0 = No need for hazard unit to check)

    //Outputs from ID/EX pipeline reg(Driven to EX stage)
    output reg [31:0] id_ex_pc, id_ex_pc_plus_4,
    output reg [31:0] id_ex_rdata1, id_ex_rdata2,
    output reg [31:0] id_ex_imm,
    output reg [4:0] id_ex_rs1, id_ex_rs2, id_ex_rd,
    output reg id_ex_rs1_valid, id_ex_rs2_valid,
    output reg [2:0] id_ex_funct3,
    output reg [6:0] id_ex_funct7,
    output reg [6:0] id_ex_opcode
);
    //NOP Encoding
    localparam [31:0] NOP_INSTRUCTION = 32'h0000_0013;

    wire [6:0] raw_opcode = if_id_instr[6:0];
    wire [4:0] raw_rd     = if_id_instr[11:7];
    wire [2:0] raw_funct3 = if_id_instr[14:12];
    wire [4:0] raw_rs1    = if_id_instr[19:15];
    wire [4:0] raw_rs2    = if_id_instr[24:20];
    wire [6:0] raw_funct7 = if_id_instr[31:25];

    assign id_rs1 = raw_rs1;
    assign id_rs2 = raw_rs2;

    reg rs1_valid, rs2_valid;
    always@(*) begin
        case(raw_opcode) 
            7'b0110011: begin // R-type
                rs1_valid = (raw_rs1 != 5'd0);
                rs2_valid = (raw_rs2 != 5'd0);
            end
            7'b0010011, // I-type ALU
            7'b0000011, // I type LOAD
            7'b1100111: begin // I type JALR
                rs1_valid = (raw_rs1 != 5'd0);
                rs2_valid = 1'b0; //Bits [24:20] are immediate, not rs2
            end

            7'b0100011: begin // S type store(sw, sb): uses both rs1 and rs2
                rs1_valid = (raw_rs1 != 5'd0);
                rs2_valid = (raw_rs2 != 5'd0);
            end

            7'b1100011: begin // B type branch(compares rs1 and rs2)
                rs1_valid = (raw_rs1 != 5'd0);
                rs2_valid = (raw_rs2 != 5'd0);
            end

            7'b0110111, //U type LUI
            7'b0010111, //U type AUIPC
            7'b1101111: begin //J type JAL
                rs1_valid = 1'b0; //No source registers are needed
                rs2_valid = 1'b0;
            end
            default: begin
                rs1_valid = 1'b0;
                rs2_valid = 1'b0;
            end
        endcase
    end
    assign id_rs1_valid = rs1_valid;
    assign id_rs2_valid = rs2_valid;

    wire [31:0] id_rdata1, id_rdata2;
    wire [31:0] id_imm;

    //Register File
    riscv_regfile u_regfile (
        .clk(clk),
        .rs1(raw_rs1),
        .rs2(raw_rs2),
        .rdata1(id_rdata1),
        .rdata2(id_rdata2),
        .reg_write(wb_reg_write),
        .rd(wb_rd),
        .w_data(wb_wdata)
    );

    //Immediate Generator
    riscv_imm_gen u_imm_gen(
        .instr(if_id_instr),
        .imm(id_imm)
    );

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            id_ex_pc <= 32'd0;
            id_ex_pc_plus_4 <= 32'd0;
            id_ex_rdata1 <= 32'd0;
            id_ex_rdata2 <= 32'd0;
            id_ex_imm <= 32'd0;
            id_ex_rs1 <= 5'd0;
            id_ex_rs2 <= 5'd0;
            id_ex_rs1_valid <= 1'b0;
            id_ex_rs2_valid <= 1'b0;
            id_ex_rd <= 5'd0;
            id_ex_funct3 <= 3'd0;
            id_ex_funct7 <= 7'd0;
            id_ex_opcode <= 7'b0000000; //NOP Opcode
        end 
        else if(flush_ex) begin
            id_ex_pc <= 32'd0;
            id_ex_pc_plus_4 <= 32'd0;
            id_ex_rdata1 <= 32'd0;
            id_ex_rdata2 <= 32'd0;
            id_ex_imm <= 32'd0;
            id_ex_rs1 <= 5'd0;
            id_ex_rs2 <= 5'd0;
            id_ex_rs1_valid <= 1'b0;
            id_ex_rs2_valid <= 1'b0;
            id_ex_rd <= 5'd0;
            id_ex_funct3 <= 3'd0;
            id_ex_funct7 <= 7'd0;
            id_ex_opcode <= 7'b0000000; //NOP Opcode
        end 
        else if(!stall_ex) begin
            id_ex_pc <= if_id_pc;
            id_ex_pc_plus_4 <= if_id_pc_plus_4;
            id_ex_rdata1 <= id_rdata1;
            id_ex_rdata2 <= id_rdata2;
            id_ex_imm <= id_imm;
            id_ex_rs1 <= raw_rs1;
            id_ex_rs2 <= raw_rs2;
            id_ex_rs1_valid <= id_rs1_valid;
            id_ex_rs2_valid <= id_rs2_valid;
            id_ex_rd <= raw_rd;
            id_ex_funct3 <= raw_funct3;
            id_ex_funct7 <= raw_funct7;
            id_ex_opcode <= raw_opcode;
        end
    end 

endmodule