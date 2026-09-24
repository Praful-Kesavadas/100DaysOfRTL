module riscv_alu (
    input [31:0] a,b,
    input [3:0] alu_control,
    output reg [31:0] result,
    output zero
);
    //Operation encoding
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLT  = 4'b0101; //Signed Less Than
    localparam ALU_SLTU = 4'b0110; //Unsigned less than
    localparam ALU_SLL  = 4'b0111; //Shift Left logical
    localparam ALU_SRL  = 4'b1000; //Shift Right Logical
    localparam ALU_SRA  = 4'b1001; //Shift right arithmetic
    localparam ALU_PASS = 4'b1010; //Pass input b

    wire [4:0] shift_amt = b[4:0];

    always@(*) begin
        case(alu_control)
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;
            ALU_AND: result = a & b;
            ALU_OR: result = a | b;
            ALU_XOR: result = a ^ b;
            ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            ALU_SLL: result = a << shift_amt;
            ALU_SRL: result = a >> shift_amt;
            ALU_SRA: result = $signed(a) >>> shift_amt;
            ALU_PASS: result = b;
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);
endmodule