`timescale 1ns / 1ps

module ieee754_adder_pipelined(
    input clk, nreset, valid_in,
    input sub,
    input [31:0] A, B,
    output reg valid_out, zero, overflow, underflow,
    output reg [31:0] result
);

    // -------------------------------------------------------------
    // STAGE 1: Unpacking
    // -------------------------------------------------------------
    reg stage1_valid;
    reg stage1_sign_a, stage1_sign_b_eff;
    reg [7:0] stage1_exp_a, stage1_exp_b;
    reg [23:0] stage1_mant_a, stage1_mant_b;

    always @(posedge clk or negedge nreset) begin
        if(!nreset) begin
            stage1_valid      <= 0;
            stage1_sign_a     <= 0;
            stage1_sign_b_eff <= 0;
            stage1_exp_a      <= 0;
            stage1_exp_b      <= 0;
            stage1_mant_a     <= 0;
            stage1_mant_b     <= 0;
        end
        else begin
            stage1_valid      <= valid_in;
            stage1_sign_a     <= A[31];
            stage1_sign_b_eff <= (sub) ? ~B[31] : B[31];
            stage1_exp_a      <= A[30:23];
            stage1_exp_b      <= B[30:23];
            stage1_mant_a     <= (A[30:23] == 8'd0) ? {1'b0, A[22:0]} : {1'b1, A[22:0]};
            stage1_mant_b     <= (B[30:23] == 8'd0) ? {1'b0, B[22:0]} : {1'b1, B[22:0]};
        end
    end

    // -------------------------------------------------------------
    // STAGE 2: Exponent Alignment
    // -------------------------------------------------------------
    reg stage2_valid;
    reg [24:0] stage2_aligned_a, stage2_aligned_b; 
    reg stage2_sign_a, stage2_sign_b_eff;
    reg [7:0] stage2_exp_common;

    always @(posedge clk or negedge nreset) begin
        if(!nreset) begin
            stage2_valid      <= 0;
            stage2_aligned_a  <= 0;
            stage2_aligned_b  <= 0;
            stage2_exp_common <= 0;
            stage2_sign_a     <= 0;
            stage2_sign_b_eff <= 0;
        end
        else begin
            stage2_valid      <= stage1_valid;
            stage2_sign_a     <= stage1_sign_a;
            stage2_sign_b_eff <= stage1_sign_b_eff;

            if(stage1_exp_a >= stage1_exp_b) begin
                stage2_exp_common <= stage1_exp_a;
                stage2_aligned_a  <= {1'b0, stage1_mant_a};
                stage2_aligned_b  <= {1'b0, stage1_mant_b} >> (stage1_exp_a - stage1_exp_b);
            end
            else begin
                stage2_exp_common <= stage1_exp_b;
                stage2_aligned_a  <= {1'b0, stage1_mant_a} >> (stage1_exp_b - stage1_exp_a);
                stage2_aligned_b  <= {1'b0, stage1_mant_b};
            end
        end
    end

    // -------------------------------------------------------------
    // STAGE 3: Addition / Subtraction
    // -------------------------------------------------------------
    reg stage3_valid;
    reg [7:0] stage3_exp_common;
    reg [24:0] stage3_sum_mant;
    reg stage3_sign_res;

    always @(posedge clk or negedge nreset) begin
        if(!nreset) begin
            stage3_valid      <= 0;
            stage3_sign_res   <= 0;
            stage3_exp_common <= 0;
            stage3_sum_mant   <= 0;
        end
        else begin
            stage3_valid      <= stage2_valid;
            stage3_exp_common <= stage2_exp_common;

            if(stage2_sign_a == stage2_sign_b_eff) begin // Addition
                stage3_sum_mant <= stage2_aligned_a + stage2_aligned_b;
                stage3_sign_res <= stage2_sign_a;
            end
            else begin // Subtraction
                if(stage2_aligned_a >= stage2_aligned_b) begin
                    stage3_sum_mant <= stage2_aligned_a - stage2_aligned_b;
                    stage3_sign_res <= stage2_sign_a;
                end
                else begin
                    stage3_sum_mant <= stage2_aligned_b - stage2_aligned_a;
                    stage3_sign_res <= stage2_sign_b_eff;
                end
            end
        end
    end

    // -------------------------------------------------------------
    // STAGE 4: Normalization (LZC & Exponent Adjustment)
    // -------------------------------------------------------------
    reg stage4_valid;
    reg stage4_is_zero;
    reg [23:0] stage4_norm_mant;
    //Declared as 10-bit SIGNED register for negative exponent handling
    reg signed [9:0] stage4_exp_res; 
    reg stage4_sign_res;

    integer lzc_count;
    integer i;

    always @(posedge clk or negedge nreset) begin
        if(!nreset) begin
            stage4_valid     <= 0;
            stage4_exp_res   <= 0;
            stage4_is_zero   <= 0;
            stage4_norm_mant <= 0;
            stage4_sign_res  <= 0;
        end
        else begin
            stage4_valid    <= stage3_valid;
            stage4_sign_res <= stage3_sign_res;

            if(stage3_sum_mant == 25'd0) begin // Exact Zero result
                stage4_is_zero   <= 1'b1;
                stage4_norm_mant <= 24'd0;
                stage4_exp_res   <= 10'sd0;
            end
            else if(stage3_sum_mant[24]) begin // Carry-Out Overflow (Shift right, exp + 1)
                stage4_is_zero   <= 1'b0;
                stage4_exp_res   <= $signed({2'b0, stage3_exp_common}) + 10'sd1;
                stage4_norm_mant <= stage3_sum_mant[24:1];
            end
            else if(stage3_sum_mant[23]) begin // Already Normalized (1.x format)
                stage4_is_zero   <= 1'b0;
                stage4_exp_res   <= $signed({2'b0, stage3_exp_common});
                stage4_norm_mant <= stage3_sum_mant[23:0];
            end
            else begin // Normalization Left Shift (Underflow Check)
                stage4_is_zero <= 1'b0;
                lzc_count = 0;
                for(i = 22; i >= 0; i = i-1) begin
                    if(stage3_sum_mant[i] && lzc_count == 0) begin
                        lzc_count = 23 - i;
                    end 
                end
                stage4_norm_mant <= stage3_sum_mant[23:0] << lzc_count;
                //Explicit signed subtraction prevents unsigned wrap-around
                stage4_exp_res   <= $signed({2'b0, stage3_exp_common}) - $signed({5'b0, lzc_count});
            end
        end
    end

    // -------------------------------------------------------------
    // STAGE 5: Packing, Exceptions & Output Generation
    // -------------------------------------------------------------
    always @(posedge clk or negedge nreset) begin
        if(!nreset) begin
            valid_out <= 0;
            overflow  <= 0;
            underflow <= 0;
            zero      <= 0;
            result    <= 0;
        end
        else begin
            valid_out <= stage4_valid;
            overflow  <= 0;
            underflow <= 0;
            zero      <= 0;

            if(stage4_is_zero) begin
                zero   <= 1'b1;
                result <= 32'd0;
            end 
            //Updated to 10-bit signed boundary evaluations
            else if(stage4_exp_res >= 10'sd255) begin // Exponent Overflow / Infinity
                result   <= {stage4_sign_res, 8'hFF, 23'd0};
                overflow <= 1'b1;
            end
            else if(stage4_exp_res <= 10'sd0) begin // Exponent Underflow
                result    <= {stage4_sign_res, 8'h00, stage4_norm_mant[22:0]};
                underflow <= 1'b1;
            end
            else begin
                result <= {stage4_sign_res, stage4_exp_res[7:0], stage4_norm_mant[22:0]};
            end
        end
    end
    
endmodule