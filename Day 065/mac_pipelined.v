module mac_pipelined#(parameter DATA_WIDTH = 16, parameter ACC_WIDTH = 40
)(
    input clk, nreset, start,
    input signed [DATA_WIDTH-1:0] A, B,
    input signed [ACC_WIDTH-1:0] C,
    input [1:0] op_code,
    output reg signed [ACC_WIDTH-1:0] product,
    output reg valid_out, overflow
);
    //OPcodes
    localparam CLR_LOAD = 2'b00;
    localparam MAC_ADD = 2'b01;
    localparam MAC_SUB = 2'b10;
    localparam PREADD_C = 2'b11;

    //Stage 1(Input latching)
    reg signed [DATA_WIDTH-1:0] A_reg1, B_reg1;
    reg signed [ACC_WIDTH-1:0] C_reg1;
    reg [1:0] op_code1;
    reg valid_1;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            valid_1 <= 0;
            op_code1 <= 2'b00;
            A_reg1 <= 0;
            B_reg1 <= 0;
            C_reg1 <= 0;
        end
        else begin
            valid_1 <= start;
            if(start) begin
                A_reg1 <= A;
                B_reg1 <= B;
                C_reg1 <= C;
                op_code1 <= op_code;
            end
        end
    end

    //Stage 2(Partial Product generation)
    reg signed [ACC_WIDTH-1:0] M_reg2, C_reg2;
    reg valid_2;
    reg [1:0] op_code2;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            valid_2 <= 0;
            op_code2 <= 0;
            M_reg2 <= 0;
            C_reg2 <= 0;
        end
        else begin
            valid_2 <= valid_1;
            if(valid_1) begin
                op_code2 <= op_code1;
                C_reg2 <= C_reg1;
                M_reg2 <= A_reg1 * B_reg1;
            end
        end
    end

    //Stage 3(ALU)
    reg signed [ACC_WIDTH-1:0] alu_result;
    reg alu_overflow;

    always@(*) begin
        case(op_code2) 
            CLR_LOAD: begin
                alu_result = M_reg2;
                alu_overflow = 0;
            end
            MAC_ADD: begin 
                alu_result = product + M_reg2;
                alu_overflow = (product[ACC_WIDTH-1] == M_reg2[ACC_WIDTH-1]) && 
                                (alu_result[ACC_WIDTH-1] != product[ACC_WIDTH-1]);
            end
            MAC_SUB: begin
                alu_result = product - M_reg2;
                alu_overflow = (product[ACC_WIDTH-1] != M_reg2[ACC_WIDTH-1]) && 
                           (alu_result[ACC_WIDTH-1] != product[ACC_WIDTH-1]);
            end
            PREADD_C: begin 
                alu_result = M_reg2 + C_reg2;
                alu_overflow = (M_reg2[ACC_WIDTH-1] == C_reg2[ACC_WIDTH-1]) && 
                            (alu_result[ACC_WIDTH-1] != M_reg2[ACC_WIDTH-1]);
            end
            default: begin
                alu_result   = {ACC_WIDTH{1'b0}};
                alu_overflow = 1'b0;
            end
        endcase
    end
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            valid_out <= 0;
            product <= 0;
            overflow <= 0;
        end
        else begin
            valid_out <= valid_2;
            if(valid_2) begin
                product <= alu_result;
                overflow <= alu_overflow;
            end
        end 
    end
endmodule