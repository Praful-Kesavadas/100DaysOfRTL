module riscv_ex_stage (
    input clk, nreset,

    input stall_mem, flush_mem,

    //Forwarding Controls and bypass data bus
    input [1:0] forward_a, forward_b, // 00 -> Use ID/EX reg data, 10 -> Forward from EX/MEM, 01 -> Forward from MEM/WB
    input [31:0] ex_mem_fwd_data,   // 1 cycle RAW bypass(from EX/MEM stage)
    input [31:0] mem_wb_fwd_data,   // 2 cycle RAW bypass(from MEM/WB stage)

    //Inputs from ID/EX register
    input [31:0] id_ex_pc, id_ex_pc_plus_4,
    input [31:0] id_ex_rdata1, id_ex_rdata2,
    input [31:0] id_ex_imm,
    input [4:0] id_ex_rs1, id_ex_rs2,
    input id_ex_rs1_valid, id_ex_rs2_valid,
    input [4:0] id_ex_rd,
    input [2:0] id_ex_funct3,
    input [6:0] id_ex_funct7, id_ex_opcode,

    //Branch Redirection signals(To IF Stage)
    output reg pc_src_ex,
    output reg [31:0] pc_target_ex,

    //Outputs from EX/MEM Register
    output reg [31:0] ex_mem_pc_plus_4,
    output reg [31:0] ex_mem_alu_result,
    output reg [31:0] ex_mem_wdata, //Store data for memory writes
    output reg [4:0] ex_mem_rd,
    output reg [2:0] ex_mem_funct3, //Required by MEM for byte/halfword width
    output reg [6:0] ex_mem_opcode,
    output reg ex_mem_reg_write,    //Register file write en
    output reg ex_mem_mem_read,     //Memory read en
    output reg ex_mem_mem_write     //Memory write en
);

    //OpCodes
    localparam OPC_OP       = 7'b0110011; // R-type: add, sub, and, etc.
    localparam OPC_OP_IMM   = 7'b0010011; // I-type: addi, andi, etc.
    localparam OPC_LOAD     = 7'b0000011; // I-type: lw, lh, lb, lhu, lbu
    localparam OPC_STORE    = 7'b0100011; // S-type: sw, sh, sb
    localparam OPC_BRANCH   = 7'b1100011; // B-type: beq, bne, blt, bge...
    localparam OPC_LUI      = 7'b0110111; // U-type: lui
    localparam OPC_AUIPC    = 7'b0010111; // U-type: auipc
    localparam OPC_JAL      = 7'b1101111; // J-type: jal
    localparam OPC_JALR     = 7'b1100111; // I-type: jalr

    //ALU Control Decoder
    reg [3:0] alu_control;

    always@(*) begin
        case(id_ex_opcode)
            OPC_OP: begin
                case(id_ex_funct3)
                    3'b000: alu_control = (id_ex_funct7[5]) ? 4'b0001 : 4'b0000; //Sub or add
                    3'b001: alu_control = 4'b0111; // sll
                    3'b010: alu_control = 4'b0101; // slt
                    3'b011: alu_control = 4'b0110; // sltu
                    3'b100: alu_control = 4'b0100; // xor
                    3'b101: alu_control = (id_ex_funct7[5]) ? 4'b1001 : 4'b1000; // sra or srl
                    3'b110: alu_control = 4'b0011; //or
                    3'b111: alu_control = 4'b0010; //and
                    default: alu_control = 4'b0000;
                endcase
            end
            OPC_OP_IMM: begin
                case(id_ex_funct3)
                    3'b000: alu_control = 4'b0000; //addi
                    3'b001: alu_control = 4'b0111; //slli
                    3'b010: alu_control = 4'b0101; //slti
                    3'b011: alu_control = 4'b0110; //sltiu
                    3'b100: alu_control = 4'b0100; //xori
                    3'b101: alu_control = (id_ex_funct7[5]) ? 4'b1001 : 4'b1000; // srai or srli
                    3'b110: alu_control = 4'b0011; //ori
                    3'b111: alu_control = 4'b0010; //andi 
                    default: alu_control = 4'b0000;
                endcase
            end
            OPC_LOAD, OPC_STORE: begin
                alu_control = 4'b0000; //Address gen = base + IMM(ADD)
            end
            OPC_AUIPC: begin
                alu_control = 4'b0000; //PC + IMM
            end
            OPC_LUI: begin
                alu_control = 4'b1010; //Pass IMM directly
            end
            default: alu_control = 4'b0000;
        endcase
    end

    //Forwarding MUX
    wire [31:0] fwd_rdata1 = (forward_a == 2'b10) ? ex_mem_fwd_data :
                             (forward_a == 2'b01) ? mem_wb_fwd_data :
                             (forward_a == 2'b00) ? id_ex_rdata1    : 32'hx;
    wire [31:0] fwd_rdata2 = (forward_b == 2'b10) ? ex_mem_fwd_data :
                             (forward_b == 2'b01) ? mem_wb_fwd_data :
                             (forward_b == 2'b00) ? id_ex_rdata2    : 32'hx;
    //ALU Interface
    wire [31:0] alu_in_a, alu_in_b;
    wire [31:0] alu_result;
    wire alu_zero;

    //Source A: Use PC for AUIPC, otherwise register 1
    assign alu_in_a = (id_ex_opcode == OPC_AUIPC) ? id_ex_pc : fwd_rdata1;

    //Source B: Use register 2 for R type and branch comparisons, otherwise immediate
    assign alu_in_b = (id_ex_opcode == OPC_OP || id_ex_opcode == OPC_BRANCH) ? fwd_rdata2 : id_ex_imm;

    riscv_alu u_alu(
        .a(alu_in_a),
        .b(alu_in_b),
        .alu_control(alu_control),
        .result(alu_result),
        .zero(alu_zero)
    );

    //Branch condition and target generation
    reg branch_taken;
    always@(*) begin
        case(id_ex_funct3)
            3'b000: branch_taken = (fwd_rdata1 == fwd_rdata2); //BEQ
            3'b001: branch_taken = (fwd_rdata1 != fwd_rdata2); //BNE
            3'b100: branch_taken = ($signed(fwd_rdata1) < $signed(fwd_rdata2)); //BLT
            3'b101: branch_taken = ($signed(fwd_rdata1) >= $signed(fwd_rdata2)); //BGE
            3'b110: branch_taken = fwd_rdata1 < fwd_rdata2; //BLTU
            3'b111: branch_taken = fwd_rdata1 >= fwd_rdata2; //BGEU
            default: branch_taken = 1'b0;
        endcase
    end
    
    //Next PC control resolution
    always@(*) begin
        if(id_ex_opcode == OPC_BRANCH) begin
            pc_src_ex = branch_taken;
            pc_target_ex = id_ex_pc + id_ex_imm;
        end
        else if(id_ex_opcode == OPC_JAL) begin
            pc_src_ex = 1'b1;
            pc_target_ex = id_ex_pc + id_ex_imm;
        end
        else if(id_ex_opcode == OPC_JALR) begin
            pc_src_ex = 1'b1;
            pc_target_ex = (fwd_rdata1 + id_ex_imm) & ~32'd1;
        end
        else begin
            pc_src_ex = 1'b0;
            pc_target_ex = 32'd0;
        end
    end

    //Control Signals
    wire ctrl_reg_write = (id_ex_opcode == OPC_OP ||
                           id_ex_opcode == OPC_OP_IMM ||
                           id_ex_opcode == OPC_LOAD ||
                           id_ex_opcode == OPC_LUI ||
                           id_ex_opcode == OPC_AUIPC ||
                           id_ex_opcode == OPC_JAL ||
                           id_ex_opcode == OPC_JALR) && (id_ex_rd != 5'd0);
    wire ctrl_mem_read = (id_ex_opcode == OPC_LOAD);
    wire ctrl_mem_write = (id_ex_opcode == OPC_STORE);

    //For jumps(JAL/JALR), return address PC+4 is routed to the result
    wire [31:0] ex_result = (id_ex_opcode == OPC_JAL || id_ex_opcode == OPC_JALR) ? id_ex_pc_plus_4 : alu_result;

    //EX/MEM registers
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            ex_mem_pc_plus_4 <= 32'd0;
            ex_mem_alu_result <= 32'd0;
            ex_mem_wdata <= 32'd0;
            ex_mem_rd <= 5'd0;
            ex_mem_funct3 <= 3'd0;
            ex_mem_opcode <= 7'b0010011; //NOP
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
        end
        else if(flush_mem) begin
            ex_mem_pc_plus_4 <= 32'd0;
            ex_mem_alu_result <= 32'd0;
            ex_mem_wdata <= 32'd0;
            ex_mem_rd <= 5'd0;
            ex_mem_funct3 <= 3'd0;
            ex_mem_opcode <= 7'b0010011; //NOP
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
        end
        else if(!stall_mem) begin
            ex_mem_pc_plus_4 <= id_ex_pc_plus_4;
            ex_mem_alu_result <= ex_result;
            ex_mem_wdata <= fwd_rdata2; //Stores fowarded rs2 value
            ex_mem_rd <= id_ex_rd;
            ex_mem_funct3 <= id_ex_funct3;
            ex_mem_opcode <= id_ex_opcode;
            ex_mem_reg_write <= ctrl_reg_write;
            ex_mem_mem_read <= ctrl_mem_read;
            ex_mem_mem_write <= ctrl_mem_write;
        end 
    end
endmodule