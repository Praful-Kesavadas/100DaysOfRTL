module riscv_core (
    input clk, nreset,

    //Instruction memory
    output [31:0] imem_addr,
    input [31:0] imem_rdata,

    //Data Memory 
    output [31:0] dmem_addr, dmem_wdata,
    output [3:0] dmem_wstrb,
    output dmem_en,
    input [31:0] dmem_rdata,

    // Verification 
    output retired_valid,
    output [4:0] retired_rd,
    output [31:0] retired_data,
    output trap_load_misaligned, trap_store_misaligned
);
    //Pipeline controls
    wire stall_id, stall_if, flush_ex, flush_id;
    wire [1:0] forward_a, forward_b;

    //IF stage outputs
    wire [31:0] if_id_pc, if_id_pc_plus_4, if_id_instr;

    //ID Stage Hazard check
    wire [4:0] if_id_rs1, if_id_rs2;
    wire id_rs1_valid, id_rs2_valid;

    //ID/EX Register outputs
    wire [31:0] id_ex_pc, id_ex_pc_plus_4;
    wire [31:0] id_ex_rdata1, id_ex_rdata2, id_ex_imm;
    wire [4:0] id_ex_rs1, id_ex_rs2, id_ex_rd;
    wire id_ex_rs1_valid, id_ex_rs2_valid;
    wire [2:0] id_ex_funct3;
    wire [6:0] id_ex_funct7, id_ex_opcode;

    // riscv_id_stage does NOT decode any control signals (that lives in
    // riscv_ex_stage instead). The hazard unit still needs to know whether the
    // instruction sitting in ID/EX right now is a load, so decode it here.
    localparam [6:0] OPC_LOAD = 7'b0000011;
    wire id_ex_mem_read = (id_ex_opcode == OPC_LOAD);

    //EX Stage branch/jump resolution
    wire pc_src_ex;
    wire [31:0] pc_target_ex;

    //EX/MEM outputs
    wire [31:0] ex_mem_pc_plus_4;
    wire [31:0] ex_mem_alu_result, ex_mem_wdata;
    wire [4:0] ex_mem_rd;
    wire [2:0] ex_mem_funct3;
    wire [6:0] ex_mem_opcode;
    wire ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write;

    //MEM/WB outputs
    wire [31:0] mem_wb_wdata;
    wire [4:0] mem_wb_rd;
    wire [6:0] mem_wb_opcode;
    wire mem_wb_reg_write;

    //WB Stage outputs
    wire [31:0] wb_rf_wdata;
    wire [4:0] wb_rf_rd;
    wire wb_rf_reg_write;
    wire [31:0] wb_fwd_data;

    //Harzard Detection Unit
    riscv_hazard_unit u_hazard_unit(
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_rd(id_ex_rd),
        .if_id_rs1(if_id_rs1),
        .if_id_rs2(if_id_rs2),
        .if_id_rs1_used(id_rs1_valid),
        .if_id_rs2_used(id_rs2_valid),
        .ex_branch_taken(pc_src_ex),
        .flush_ex(flush_ex),
        .stall_if(stall_if),
        .stall_id(stall_id),
        .flush_id(flush_id)
    );

    //Forwarding Unit
    riscv_forwarding_unit u_forward(
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_rd(mem_wb_rd),
        .mem_wb_reg_write(mem_wb_reg_write),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    //IF Stage
    riscv_if_stage u_if_stage(
        .clk(clk),
        .nreset(nreset),
        .stall_if(stall_if | stall_id), //Asserted identically by the hazard unit
        .flush_if(flush_id),
        .pc_src_ex(pc_src_ex),
        .pc_target_ex(pc_target_ex),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .if_id_pc(if_id_pc),
        .if_id_pc_plus_4(if_id_pc_plus_4),
        .if_id_instr(if_id_instr)
    );

    //ID Stage
    riscv_id_stage u_id(
        .clk(clk),
        .nreset(nreset),
        .stall_ex(1'b0), //Bubbles injected via flush ex, never held
        .flush_ex(flush_ex),
        .if_id_pc(if_id_pc),
        .if_id_pc_plus_4(if_id_pc_plus_4),
        .if_id_instr(if_id_instr),
        .wb_reg_write(wb_rf_reg_write),
        .wb_rd(wb_rf_rd),
        .wb_wdata(wb_rf_wdata),
        .id_rs1(if_id_rs1),
        .id_rs2(if_id_rs2),
        .id_rs1_valid(id_rs1_valid),
        .id_rs2_valid(id_rs2_valid),
        .id_ex_pc(id_ex_pc),
        .id_ex_pc_plus_4(id_ex_pc_plus_4),
        .id_ex_rdata1(id_ex_rdata1),
        .id_ex_rdata2(id_ex_rdata2),
        .id_ex_imm(id_ex_imm),
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .id_ex_rd(id_ex_rd),
        .id_ex_rs1_valid(id_ex_rs1_valid),
        .id_ex_rs2_valid(id_ex_rs2_valid),
        .id_ex_funct3(id_ex_funct3),
        .id_ex_funct7(id_ex_funct7),
        .id_ex_opcode(id_ex_opcode)
    );

    //EX Stage
    riscv_ex_stage u_ex(
        .clk(clk),
        .nreset(nreset),
        .stall_mem(1'b0),
        .flush_mem(1'b0),
        .forward_a(forward_a),
        .forward_b(forward_b),
        .ex_mem_fwd_data(ex_mem_alu_result),
        .mem_wb_fwd_data(wb_fwd_data),
        .id_ex_pc(id_ex_pc),
        .id_ex_pc_plus_4(id_ex_pc_plus_4),
        .id_ex_rdata1(id_ex_rdata1),
        .id_ex_rdata2(id_ex_rdata2),
        .id_ex_imm(id_ex_imm),
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .id_ex_rs1_valid(id_ex_rs1_valid),
        .id_ex_rs2_valid(id_ex_rs2_valid),
        .id_ex_rd(id_ex_rd),
        .id_ex_funct3(id_ex_funct3),
        .id_ex_funct7(id_ex_funct7),
        .id_ex_opcode(id_ex_opcode),
        .pc_src_ex(pc_src_ex),
        .pc_target_ex(pc_target_ex),
        .ex_mem_pc_plus_4(ex_mem_pc_plus_4),
        .ex_mem_wdata(ex_mem_wdata),
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_funct3(ex_mem_funct3),
        .ex_mem_opcode(ex_mem_opcode),
        .ex_mem_reg_write(ex_mem_reg_write),
        .ex_mem_mem_read(ex_mem_mem_read),
        .ex_mem_mem_write(ex_mem_mem_write)
    );

    //MEM Stage
    riscv_mem_stage u_mem(
        .clk(clk),
        .nreset(nreset),
        .stall_wb(1'b0),
        .flush_wb(1'b0),
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_wdata(ex_mem_wdata),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_funct3(ex_mem_funct3),
        .ex_mem_opcode(ex_mem_opcode),
        .ex_mem_reg_write(ex_mem_reg_write),
        .ex_mem_mem_read(ex_mem_mem_read),
        .ex_mem_mem_write(ex_mem_mem_write),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb),
        .dmem_en(dmem_en),
        .dmem_rdata(dmem_rdata),
        .trap_load_misaligned(trap_load_misaligned),
        .trap_store_misaligned(trap_store_misaligned),
        .mem_wb_wdata(mem_wb_wdata),
        .mem_wb_rd(mem_wb_rd),
        .mem_wb_opcode(mem_wb_opcode),
        .mem_wb_reg_write(mem_wb_reg_write)
    );
    
    //WB Stage
    riscv_wb_stage u_wb_stage (
        .mem_wb_wdata(mem_wb_wdata),
        .mem_wb_rd(mem_wb_rd),
        .mem_wb_opcode(mem_wb_opcode),
        .mem_wb_reg_write(mem_wb_reg_write),
        .wb_rf_wdata(wb_rf_wdata),
        .wb_rf_rd(wb_rf_rd),
        .wb_rf_reg_write(wb_rf_reg_write),
        .wb_fwd_data(wb_fwd_data),
        .wb_retired_valid(retired_valid),
        .wb_retired_rd(retired_rd),
        .wb_retired_data(retired_data)
    );
endmodule
