module riscv_if_stage #(
    parameter [31:0] RESET_VECTOR = 32'h0000_0000
)(
    input clk, nreset,

    //Hazard & control inputs from EX/Hazard Unit
    input stall_if, // 1 = FREEZE PC and IF/ID Pipeline register
    input flush_if, // 1 = Insert NOP into IF/ID reg
    input pc_src_ex,// Select line for mux: 0 = PC+4, 1 = Branch/Jump target
    input [31:0] pc_target_ex, // Target address(For jump)

    //Memory Interface(To Instruction memory)
    output [31:0] imem_addr,
    input [31:0] imem_rdata,

    //IF/ID pipeline register outputs(Driven to ID Stage)
    output reg [31:0] if_id_pc, if_id_pc_plus_4,
    output reg [31:0] if_id_instr
);
    // RV32I NOP Encoding: addi x0, x0, 0
    localparam [31:0] NOP_INSTRUCTION = 32'h0000_0000;

    //Internal Regs
    reg [31:0] pc_reg, pc_next;
    wire [31:0] pc_plus_4;

    assign pc_plus_4 = pc_reg + 32'd4;
    assign imem_addr = pc_reg;

    //MUX for next PC
    always@(*) begin
        if(pc_src_ex) pc_next = pc_target_ex;
        else pc_next = pc_plus_4;
    end

    //PC reg
    always@(posedge clk or negedge nreset) begin
        if(!nreset) pc_reg <= RESET_VECTOR;
        else if(!stall_if || pc_src_ex) pc_reg <= pc_next;
    end

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            if_id_pc <= RESET_VECTOR;
            if_id_pc_plus_4 <= RESET_VECTOR + 32'd4;
            if_id_instr <= NOP_INSTRUCTION;
        end
        else if(flush_if) begin
            if_id_pc <= 32'd0;
            if_id_pc_plus_4 <= 32'd0;
            if_id_instr <= NOP_INSTRUCTION;
        end
        else if(!stall_if) begin
            if_id_pc <= pc_reg;
            if_id_pc_plus_4 <= pc_plus_4;
            if_id_instr <= imem_rdata;  
        end
    end 
endmodule
