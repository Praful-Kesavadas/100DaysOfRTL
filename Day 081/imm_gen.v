module riscv_imm_gen (
    input [31:0] instr,
    output reg [31:0] imm
);
    wire [6:0] opcode = instr[6:0];

    //Standard RV32I Base Opcodes
    localparam OPC_OP_IMM = 7'b0010011; // addi...
    localparam OPC_LOAD = 7'b0000011;   // lb, lh, lw, lbu, lhu
    localparam OPC_JALR = 7'b1100111;   // jalr
    localparam OPC_STORE = 7'b0100011;  // sb, sh, sw
    localparam OPC_BRANCH = 7'b1100011; // beq, bne, blt, bge, bltu, bgeu
    localparam OPC_LUI = 7'b0110111;    // lui
    localparam OPC_AUIPC = 7'b0010111;  // auipc
    localparam OPC_JAL = 7'b1101111;    // jal

    always@(*) begin
        case(opcode)
            // I-type Immediate
            OPC_OP_IMM, OPC_LOAD, OPC_JALR: begin
                imm = {{20{instr[31]}}, instr[31:20]};
            end

            // S-type immediate
            OPC_STORE: begin
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end

            // B-type immediates
            OPC_BRANCH: begin
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            end

            // U-type immediate(shifted upper 20 bits)
            OPC_AUIPC, OPC_LUI: begin
                imm = {instr[31:12], 12'h00};
            end

            // J-type
            OPC_JAL: begin
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            end

            default: begin
                imm = 32'd0;
            end
        endcase
    end

endmodule