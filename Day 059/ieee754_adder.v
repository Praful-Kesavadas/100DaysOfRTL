`timescale 1ns / 1ps

module ieee754_adder_fsm(
    input clk, nreset, start,
    input sub, 
    input [31:0] A, B,
    output reg [31:0] result,
    output reg valid, overflow, underflow, zero
);

    // FSM States
    localparam IDLE    = 3'd0;
    localparam ALIGN   = 3'd1;
    localparam ADD_SUB = 3'd2;
    localparam NORM    = 3'd3;
    localparam PACK    = 3'd4;

    reg [2:0] state;

    // Unpacked regs
    reg sign_a, sign_b_eff;
    reg [7:0] exp_a, exp_b;
    reg [23:0] mant_a, mant_b; // Including explicit leading bit

    // Alignment and Data path regs
    reg [7:0] exp_common;
    reg [24:0] aligned_a, aligned_b;
    reg [24:0] sum_mant;
    reg sign_res;

    // Normalized regs
    // CHANGE 1: Declared as 10-bit SIGNED register to handle negative exponent underflow
    reg signed [9:0] exp_res; 
    reg [23:0] norm_mant;

    integer i;
    reg [4:0] lzc;
    reg is_zero;

    always @(posedge clk or negedge nreset) begin
        if(!nreset) begin
            state       <= IDLE;
            valid       <= 0;
            result      <= 0;
            overflow    <= 0;
            underflow   <= 0;
            zero        <= 0;
            sign_a      <= 0;
            sign_b_eff  <= 0;
            exp_a       <= 0;
            exp_b       <= 0;
            mant_a      <= 0;
            mant_b      <= 0;
            exp_common  <= 0;
            aligned_a   <= 0;
            aligned_b   <= 0;
            sum_mant    <= 0;
            sign_res    <= 0;
            exp_res     <= 0;
            norm_mant   <= 0;
            is_zero     <= 0;
        end
        else begin
            case(state)
                // Wait for Start Signal
                IDLE: begin
                    valid     <= 0;
                    overflow  <= 0;
                    underflow <= 0;
                    zero      <= 0;

                    if(start) begin
                        sign_a     <= A[31];
                        sign_b_eff <= (sub) ? ~B[31] : B[31];
                        exp_a      <= A[30:23];
                        exp_b      <= B[30:23];
                        mant_a     <= (A[30:23] == 8'd0) ? {1'd0, A[22:0]} : {1'b1, A[22:0]};
                        mant_b     <= (B[30:23] == 8'd0) ? {1'd0, B[22:0]} : {1'b1, B[22:0]};
                        state      <= ALIGN;
                    end
                end

                // Align operands
                ALIGN: begin
                    if(exp_a >= exp_b) begin
                        exp_common <= exp_a;
                        aligned_a  <= {1'b0, mant_a};
                        aligned_b  <= {1'b0, mant_b} >> (exp_a - exp_b);
                    end
                    else begin
                        exp_common <= exp_b;
                        aligned_a  <= {1'b0, mant_a} >> (exp_b - exp_a);
                        aligned_b  <= {1'b0, mant_b};
                    end
                    state <= ADD_SUB;
                end

                // Execute effective addition / subtraction
                ADD_SUB: begin
                    if(sign_a == sign_b_eff) begin
                        sum_mant <= aligned_a + aligned_b;
                        sign_res <= sign_a;
                    end
                    else begin
                        if(aligned_a >= aligned_b) begin
                            sum_mant <= aligned_a - aligned_b;
                            sign_res <= sign_a;
                        end
                        else begin
                            sum_mant <= aligned_b - aligned_a;
                            sign_res <= sign_b_eff;
                        end
                    end
                    state <= NORM;
                end

                // Normalization State
                NORM: begin
                    if(sum_mant == 25'd0) begin // Exact Zero result
                        is_zero   <= 1'b1;
                        norm_mant <= 24'd0;
                        exp_res   <= 10'sd0;
                    end
                    else if(sum_mant[24]) begin // Carry-Out Overflow (Shift right, exp + 1)
                        is_zero   <= 1'b0;
                        norm_mant <= sum_mant[24:1];
                        exp_res   <= $signed({2'b0, exp_common}) + 10'sd1;
                    end
                    else if(sum_mant[23]) begin // Already Normalized (1.x format)
                        is_zero   <= 1'b0;
                        norm_mant <= sum_mant[23:0];
                        exp_res   <= $signed({2'b0, exp_common});
                    end
                    else begin // Normalization Left Shift (Underflow Check)
                        is_zero <= 1'b0;
                        lzc = 0;
                        for(i = 22; i >= 0; i = i-1) begin
                            if(sum_mant[i] && lzc == 0) begin
                                lzc = 23 - i;
                            end
                        end
                        norm_mant <= sum_mant[23:0] << lzc;
                        
                        // CHANGE 2: Explicit signed calculation to handle negative exponents
                        exp_res   <= $signed({2'b0, exp_common}) - $signed({5'b0, lzc});
                    end
                    state <= PACK;
                end

                // Pack Result & Assert Exception Flags
                PACK: begin
                    valid <= 1'b1;
                    if(is_zero) begin
                        result <= 32'd0;
                        zero   <= 1'b1;
                    end
                    // CHANGE 3: Updated to 10-bit signed boundary evaluations
                    else if(exp_res >= 10'sd255) begin // Exponent Overflow / Infinity
                        result   <= {sign_res, 8'hFF, 23'd0}; 
                        overflow <= 1'b1;
                    end
                    else if(exp_res <= 10'sd0) begin // Exponent Underflow
                        result    <= {sign_res, 8'h00, norm_mant[22:0]};
                        underflow <= 1'b1;
                    end
                    else begin
                        result <= {sign_res, exp_res[7:0], norm_mant[22:0]};
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule