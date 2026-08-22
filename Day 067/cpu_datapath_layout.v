module cpu_datapath_layout #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 8
)(
    input clk, nreset,
    output [ADDR_WIDTH-1:0] pc_out,
    output [DATA_WIDTH-1:0] alu_result_out
);
    //Program Counter
    reg [ADDR_WIDTH-1:0] pc;
    assign pc_out = pc;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            pc <= 0;
        end
        else begin
            pc <= pc + 1'b1; 
        end
    end 

    //Static Instruction Memory(Hardcoded in a ROM)
    reg [15:0] imem [0: (1<<ADDR_WIDTH) - 1];
    wire [15:0] instruction = imem[pc];

    wire [3:0] opcode = instruction[15:12]; //4 MSB of instruction is the opcode
    wire [3:0] rd     = instruction[11:8]; //Next 4 is for the destination register index
    wire [3:0] rs1    = instruction[7:4]; //Next 4 is the source reg 1
    wire [3:0] rs2    = instruction[3:0]; //4 LSB is for source reg 2

    integer j;
    initial begin
        for (j = 0; j < (1<<ADDR_WIDTH); j = j + 1) begin
            imem[j] = 16'h0000;
        end
        // Inst 0: R1 = R0 + R0  -> (0 + 0 = 0)
        imem[0] = 16'h0100;
        // Inst 1: R2 = R1 + R1  
        imem[1] = 16'h0211;
        // Inst 2: R3 = R1 & R2  
        imem[2] = 16'h2312;
        // Inst 3: R4 = R2 | R3  
        imem[3] = 16'h3423;
        // Inst 4: R5 = R2 ^ R3  
        imem[4] = 16'h4523;
        // Inst 5: R6 = R4 << 1  
        imem[5] = 16'h5640;
    end

    //Register File
    reg [DATA_WIDTH-1:0] reg_file [0:15];
    wire [DATA_WIDTH-1:0] src_a = reg_file[rs1];
    wire [DATA_WIDTH-1:0] src_b = reg_file[rs2];

    //ALU
    reg [DATA_WIDTH-1:0] alu_out;
    always@(*) begin
        case(opcode) 
            4'b0000: alu_out = src_a + src_b;
            4'b0001: alu_out = src_a - src_b;
            4'b0010: alu_out = src_a & src_b;
            4'b0011: alu_out = src_a | src_b;
            4'b0100: alu_out = src_a ^ src_b;
            4'b0101: alu_out = src_a << 1;
            4'b0110: alu_out = src_a >> 1;
            default: alu_out = src_a;
        endcase
    end
    assign alu_result_out = alu_out;

    integer i;
    always @(posedge clk or negedge nreset) begin
        if (!nreset) begin
            // Initialize register values so arithmetic doesn't evaluate on X
            reg_file[0]  <= 16'd10; // Seed initial data
            reg_file[1]  <= 16'd20; // Seed initial data
            for (i = 2; i < 16; i = i + 1) begin
                reg_file[i] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            reg_file[rd] <= alu_out; // Write back calculated result
        end
    end
endmodule