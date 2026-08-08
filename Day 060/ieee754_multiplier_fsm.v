module ieee754_multiplier_fsm(
    input clk, nreset, start,
    input [31:0] A, B,
    output reg [31:0] result,
    output reg valid, underflow, overflow, zero
);

    //FSM States
    localparam IDLE = 2'd0;
    localparam MULT = 2'd1;
    localparam NORM = 2'd2;
    localparam PACK = 2'd3;

    wire input_zero = (A == 0 | B == 0);
    reg [1:0] state;

    //Unpacking
    reg sign_a, sign_b;
    reg [7:0] exp_a, exp_b;
    reg [23:0] mant_a, mant_b;

    //Multiplication registers
    reg sign_res;
    reg signed [9:0] exp_int;
    reg [47:0] prod_mant;

    //Normalization outputs 
    reg [23:0] prod_norm;
    reg signed [9:0] exp_res;
    reg is_zero;
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            state <= IDLE;
            sign_a <= 0;
            sign_b <= 0;
            exp_a <= 0;
            exp_b <= 0;
            mant_a <= 0;
            mant_b <= 0;
            result <= 0;
            valid <= 0;
            underflow <= 0;
            overflow <= 0;
            zero <= 0;
            sign_res <= 0;
            exp_int <= 0;
            prod_mant <= 0;
            exp_res <= 0;
            prod_norm <= 0;
            is_zero <= 0;
        end
        else begin
            case(state)
                //Wait for start 
                IDLE: begin
                    result <= 0;
                    valid <= 0;
                    underflow <= 0;
                    zero <= 0;

                    if(start) begin
                        sign_a <= A[31];
                        sign_b <= B[31];
                        exp_a <= A[30:23];
                        exp_b <= B[30:23];
                        mant_a <= (A[30:23] == 8'd0) ? {1'd0, A[22:0]} : {1'd1, A[22:0]};
                        mant_b <= (B[30:23] == 8'd0) ? {1'd0, B[22:0]} : {1'd1, B[22:0]};
                        if(A[30:0] == 31'd0 || B[30:0] == 31'd0) begin
                            is_zero <= 1'b1;
                            state <= PACK;
                        end
                        else begin
                            is_zero <= 1'b0;
                            state <= MULT;
                        end
                    end
                end
                MULT: begin
                    prod_mant <= mant_a * mant_b;
                    exp_int <= $signed({2'b0, exp_a}) + $signed({2'b0, exp_b}) - 10'sd127;
                    state <= NORM;
                    sign_res <= sign_a ^ sign_b;
                end
                NORM: begin
                    if(prod_mant == 48'd0) begin 
                        is_zero <= 1;
                        prod_norm <= 0;
                        exp_res <= 0;
                    end
                    else if(prod_mant[47]) begin
                        is_zero <= 0;
                        exp_res <= exp_int + 1'b1;
                        prod_norm <= prod_mant[46:24];
                    end
                    else begin
                        is_zero <= 0;
                        exp_res <= exp_int;
                        prod_norm <= prod_mant[45:23];
                    end
                    state <= PACK;
                end
                PACK: begin
                    valid <= 1'b1;
                    if(is_zero) begin
                        result <= 32'd0;
                        zero <= 1'b1;
                    end
                    else if(exp_res >= 10'sd255) begin
                        result <= {sign_res, 8'hFF, 23'd0};
                        overflow <= 1'b1;
                    end
                    else if(exp_res <= 10'sd0) begin
                        result <= {sign_res, 8'h00, prod_norm[22:0]};
                        underflow <= 1'b1;
                    end
                    else begin
                        result <= {sign_res, exp_res[7:0], prod_norm[22:0]};
                    end
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule