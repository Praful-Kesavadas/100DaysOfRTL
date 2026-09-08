module multi_cycle_decoder(
    input clk, nreset,
    input [5:0] opcode, //6 bit instruction opcodes
    input zero_flag,

    output reg pc_write,        // Unconditional PC update enable(for fetch/jump ops)
    output reg pc_write_cond,   // Conditional PC update enable(for BEQ)
    output reg i_or_d,          // 0 -> Select PC(Fetch) , 1 -> Select ALUOut(Data Mem)
    output reg mem_read,        // Memory Read enable
    output reg mem_write,       // Memory Write Enable
    output reg ir_write,        // Instruction Write Enable pin
    output reg reg_write,       // Register file write enable
    output reg mem_to_reg,      // 0: ALUOut, 1: Memory Data Reister
    output reg alu_src_a,       // 0: PC, 1: Reg A
    output reg [1:0] alu_src_b, // 00: Reg B, 01: +1(Next PC), 10: Immediate
    output reg [1:0] alu_op,    // 00: Add, 01: Subtract, 10: R-type function decode
    output reg [1:0] pc_source, // 00: ALU Result, 01: ALUOut Reg, 10: Jump target
    output [3:0] current_state  // State of system
);
    //OpCodes
    localparam OPC_RTYPE = 6'b000000;   // ADD, SUB..
    localparam OPC_ADDI  = 6'b001000;   // Immediate Computational Instructions
    localparam OPC_LW    = 6'b100011;   // Memory Load
    localparam OPC_SW    = 6'b101011;   // Memory Store
    localparam OPC_BEQ   = 6'b000100;   // Conditional Branch
    localparam OPC_JAL   = 6'b000010;   // Direct Jump(Unconditional)

    //FSM States
    localparam S_FETCH = 4'd0;
    localparam S_DECODE = 4'd1;
    localparam S_MEM_ADR = 4'd2;
    localparam S_MEM_RD = 4'd3;
    localparam S_MEM_WB = 4'd4;
    localparam S_MEM_WR = 4'd5;
    localparam S_EXEC_R = 4'd6;
    localparam S_ALU_WB = 4'd7;
    localparam S_EXEC_I = 4'd8;
    localparam S_BRANCH = 4'd9;
    localparam S_JUMP = 4'd10;

    reg [3:0] state, next_state;
    assign current_state = state;

    //State Update
    always@(posedge clk or negedge nreset) begin
        if(!nreset) state <= S_FETCH;
        else state <= next_state;
    end

    //Next state logic
    always@(*) begin
        next_state = state;
        case(state)
            S_FETCH: begin
                next_state = S_DECODE;
            end
            S_DECODE: begin
                case(opcode)
                    OPC_LW, OPC_SW: next_state = S_MEM_ADR;
                    OPC_RTYPE: next_state = S_EXEC_R;
                    OPC_ADDI: next_state = S_EXEC_I;
                    OPC_BEQ: next_state = S_BRANCH;
                    OPC_JAL: next_state = S_JUMP;
                    default: next_state = S_FETCH;
                endcase
            end
            S_MEM_ADR: begin
                if(opcode == OPC_LW) next_state = S_MEM_RD;
                else next_state = S_MEM_WR;
            end
            S_MEM_RD: begin
                next_state = S_MEM_WB;
            end
            S_MEM_WB: begin
                next_state = S_FETCH;
            end
            S_MEM_WR: begin
                next_state = S_FETCH;
            end
            S_EXEC_R: begin
                next_state = S_ALU_WB;
            end
            S_EXEC_I: begin
                next_state = S_ALU_WB;
            end
            S_ALU_WB: begin
                next_state = S_FETCH;
            end
            S_BRANCH: begin
                next_state = S_FETCH;
            end
            S_JUMP: begin
                next_state = S_FETCH;
            end
            default: next_state = S_FETCH;
        endcase
    end

    //State wise logics
    always@(*) begin
        // Safe Default Outputs
        pc_write      = 1'b0;
        pc_write_cond = 1'b0;
        i_or_d        = 1'b0;
        mem_read      = 1'b0;
        mem_write     = 1'b0;
        ir_write      = 1'b0;
        reg_write     = 1'b0;
        mem_to_reg    = 2'b00;
        alu_src_a     = 1'b0;
        alu_src_b     = 2'b00;
        alu_op        = 2'b00;
        pc_source     = 2'b00;

        case(state) 
            // Fetch instruction and advance PC by 1
            S_FETCH: begin
                mem_read = 1'b1;
                ir_write = 1'b1;
                alu_src_a = 1'b0;
                alu_src_b = 2'b01;
            end
            //Decode and pre-calculate branch target
            S_DECODE: begin
                alu_src_a = 1'b0; //Select PC
                alu_src_b = 2'b10; //Select Immediate offset
                alu_op = 2'b00; //Add operation(Branch target =  PC + Offset)
            end
            //Effective address computation(For LW and SW operations)
            S_MEM_ADR: begin
                alu_src_a = 1'b1; // Select Reg A
                alu_src_b = 2'b10; //Select sign extended immediate
                alu_op = 2'b00; //Address = A + imm
            end
            //Data Memory Read for LW
            S_MEM_RD: begin
                mem_read = 1'b1;
                i_or_d = 1'b1; //memory address = aluout
            end
            //Register File writeback from mem data reg
            S_MEM_WB: begin
                reg_write = 1'b1;
                mem_to_reg = 1'b1; //Write data to reg from mem
            end
            //Data Memory Write for SW operation
            S_MEM_WR: begin
                mem_write = 1'b1;
                i_or_d = 1'b1; //Address from ALUOut
            end
            //Execute ALU Operation(For R type)
            S_EXEC_R: begin
                alu_src_a = 1'b1; //Reg A
                alu_src_b = 2'b00; //Reg B
                alu_op = 2'b10; //Function driven R-type decode
            end
            //Execute Immediate ALU Operation(For I-type)
            S_EXEC_I: begin
                alu_src_a = 1'b1; //Reg A
                alu_src_b = 2'b10; //Immediate
                alu_op = 2'b00; //Add operation for ADDI
            end
            //Write back ALU result to register file(for both R-type and I-type instruction)
            S_ALU_WB: begin
                reg_write = 1'b1;
                mem_to_reg = 1'b0; // ALU out to reg
            end
            //For BEQ 
            S_BRANCH: begin
                alu_src_a = 1'b1; //Reg A
                alu_src_b = 2'b00; //Reg B
                alu_op = 2'b01; //Sub(A-B)
                pc_source = 2'b01; // ALUOut register(Target)
                pc_write_cond = 1'b1; //Conditional write 
            end
            //For unconditional jump(JAL)
            S_JUMP: begin
                pc_source = 2'b10; //Jump target
                pc_write = 1'b1;
            end
        endcase
    end
endmodule