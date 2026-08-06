module alu#(parameter DATA_WIDTH = 16
)(
    input clk, nreset, 
    input [3:0] alu_op,
    input [DATA_WIDTH-1:0] A, B,
    output zero, negative,
    output reg carry, overflow,
    output reg [DATA_WIDTH-1:0] result
);
    // Different opcodes
    localparam ADD = 4'd0;
    localparam SUB = 4'd1;
    localparam INC = 4'd2;
    localparam DEC = 4'd3;
    localparam AND = 4'd4;
    localparam OR  = 4'd5;
    localparam XOR = 4'd6;
    localparam NOT = 4'd7;
    localparam NAND= 4'd8;
    localparam NOR = 4'd9;
    localparam SLL = 4'd10; //Logical Left Shift
    localparam SRL = 4'd11; //Logical Right Shift
    localparam SRA = 4'd12; //Arithmetic Right Shift
    localparam ROL = 4'd13; //Rotate A left by B
    localparam ROR = 4'd14; //Rotate A right by B
    localparam PASS= 4'd15;

    //Shift bits
    localparam SHIFT_BITS = $clog2(DATA_WIDTH);
    wire [SHIFT_BITS-1:0] shift_amt = B[SHIFT_BITS-1:0];

    //Select B_eff and C_in for different cases of Opcodes
    reg [DATA_WIDTH-1:0] B_eff;
    reg C_in;
    always@(*) begin
        case(alu_op)
            ADD: begin
                B_eff = B;
                C_in = 1'b0;
            end
            SUB: begin
                B_eff = ~B;
                C_in = 1'b1;
            end
            INC: begin
                B_eff = 0;
                C_in = 1'b1;
            end
            DEC: begin
                B_eff = {DATA_WIDTH{1'b1}};
                C_in = 0;
            end
            default: begin
                B_eff = 0;
                C_in = 0;
            end
        endcase
    end

    //Adder
    wire [DATA_WIDTH:0] arith_full = A + B_eff + C_in;
    wire [DATA_WIDTH-1:0] arith_result = arith_full[DATA_WIDTH-1:0];
    wire arith_carry = arith_full[DATA_WIDTH];
    wire arith_overflow = (A[DATA_WIDTH-1] == B_eff[DATA_WIDTH-1]) && (arith_result[DATA_WIDTH-1] != A[DATA_WIDTH-1]);

    //Full operational mux
    reg [DATA_WIDTH-1:0] result_comb;
    reg carry_comb, overflow_comb;

    always@(*) begin
        carry_comb = 0;
        overflow_comb = 0;

        case(alu_op) 
            ADD, SUB, INC, DEC: begin
                result_comb = arith_result;
                carry_comb = arith_carry;
                overflow_comb = arith_overflow;
            end
            AND: result_comb = A & B;
            OR: result_comb = A | B;
            XOR: result_comb = A ^ B;
            NOT: result_comb = ~A;
            NAND: result_comb = ~(A & B);
            NOR: result_comb = ~(A | B);

            SLL: result_comb = A << shift_amt;
            SRL: result_comb = A >> shift_amt;
            SRA: result_comb = $signed(A) >>> shift_amt;
            ROL: result_comb = (A << shift_amt) | (A >> (DATA_WIDTH - shift_amt));
            ROR: result_comb = (A >> shift_amt) | (A << (DATA_WIDTH - shift_amt));

            PASS: result_comb = A;
            default: result_comb = 0;
        endcase
    end

    //Output Flipflop
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            result <= 0;
            carry <= 0;
            overflow <= 0;
        end
        else begin
            result <= result_comb;
            carry <= carry_comb;
            overflow <= overflow_comb;
        end
    end

    //Output assignments
    assign zero = (result == {DATA_WIDTH{1'b0}});
    assign negative = result[DATA_WIDTH-1];
endmodule