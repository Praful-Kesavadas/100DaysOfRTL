module riscv_mem_stage (
    input clk, nreset,

    input stall_wb, flush_wb,

    //Inputs from EX/MEM Register
    input [31:0] ex_mem_alu_result,
    input [31:0] ex_mem_wdata,
    input [4:0] ex_mem_rd,
    input [2:0] ex_mem_funct3,
    input [6:0] ex_mem_opcode,
    input ex_mem_reg_write,
    input ex_mem_mem_write, ex_mem_mem_read,

    //External Data Memory Interface
    output [31:0] dmem_addr,
    output reg [31:0] dmem_wdata,
    output reg [3:0] dmem_wstrb,
    output dmem_en,
    input [31:0] dmem_rdata,

    // Exception/Trap Flags
    output trap_store_misaligned, trap_load_misaligned,

    //Outputs from MEM/WB register
    output reg [31:0] mem_wb_wdata,
    output reg [4:0] mem_wb_rd,
    output reg [6:0] mem_wb_opcode,
    output reg mem_wb_reg_write
);
    wire [1:0] byte_offset = ex_mem_alu_result[1:0];

    //Word Aligned address(LSBs zero)
    assign dmem_addr = {ex_mem_alu_result[31:2], 2'b00};

    //Misaligned detection
    wire misaligned_half = (ex_mem_funct3[1:0] == 2'b01) && (byte_offset[0] != 1'b0);
    wire misaligned_word = (ex_mem_funct3[1:0] == 2'b10) && (byte_offset != 2'b00);
    wire is_misaligned = (ex_mem_mem_read | ex_mem_mem_write) && (misaligned_half | misaligned_word);

    assign trap_load_misaligned = ex_mem_mem_read & is_misaligned & ~flush_wb;
    assign trap_store_misaligned = ex_mem_mem_write & is_misaligned & ~flush_wb;

    //Suppress enable if misaligned to protext memory
    assign dmem_en = (ex_mem_mem_write | ex_mem_mem_read) & ~is_misaligned & ~flush_wb;

    //Data Steering: Raw combinational path
    always @(*) begin
        case (ex_mem_funct3)
            3'b000:  dmem_wdata = {4{ex_mem_wdata[7:0]}};
            3'b001:  dmem_wdata = {2{ex_mem_wdata[15:0]}};
            default: dmem_wdata = ex_mem_wdata;
        endcase
    end
    //Strobe Generation
    always @(*) begin
        if (ex_mem_mem_write && !is_misaligned && !flush_wb) begin
            case (ex_mem_funct3)
                3'b000:  dmem_wstrb = 4'b0001 << byte_offset;
                3'b001:  dmem_wstrb = byte_offset[1] ? 4'b1100 : 4'b0011;
                3'b010:  dmem_wstrb = 4'b1111;
                default: dmem_wstrb = 4'b0000;
            endcase
        end else begin
            dmem_wstrb = 4'b0000;
        end
    end

    //Load Alignment and Sign/zero extension
    reg [7:0] loaded_byte;
    reg [15:0] loaded_half;

    always@(*) begin
        case(byte_offset)
            2'b00: loaded_byte = dmem_rdata[7:0];
            2'b01: loaded_byte = dmem_rdata[15:8];
            2'b10: loaded_byte = dmem_rdata[23:16];
            2'b11: loaded_byte = dmem_rdata[31:24];
        endcase
    end
    always@(*) begin
        loaded_half = byte_offset[1] ? dmem_rdata[31:16] : dmem_rdata[15:0];      
    end

    reg [31:0] load_data;
    always@(*) begin
        if(is_misaligned) load_data = 32'd0;
        else begin
            case(ex_mem_funct3)
                3'b000: load_data = {{24{loaded_byte[7]}}, loaded_byte}; //LB(signed byte)
                3'b001: load_data = {{16{loaded_half[15]}}, loaded_half}; //LH(signed half)
                3'b010: load_data = dmem_rdata; //LW(load word)
                3'b100: load_data = {24'd0, loaded_byte}; //LBU(unsigned byte)
                3'b101: load_data = {16'd0, loaded_half}; //LHU(unsigned halfword)
                default: load_data = dmem_rdata; //Anyother will do LW
            endcase
        end
    end

    //Writeback MUX
    wire [31:0] mem_stage_result = (ex_mem_mem_read) ? load_data : ex_mem_alu_result;

    //MEM/WB Regs
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            mem_wb_wdata <= 32'd0;
            mem_wb_rd <= 5'd0;
            mem_wb_opcode <= 7'b0000000; //NOP
            mem_wb_reg_write <= 1'b0;
        end
        else if(flush_wb) begin
            mem_wb_wdata <= 32'd0;
            mem_wb_rd <= 5'd0;
            mem_wb_opcode <= 7'b0000000; //NOP
            mem_wb_reg_write <= 1'b0;
        end
        else if(!stall_wb) begin
            mem_wb_wdata <= mem_stage_result;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_opcode <= ex_mem_opcode;
            mem_wb_reg_write <= ex_mem_reg_write & ~is_misaligned;
        end
    end
endmodule