module logarithmic_barrel_shifter(
    input [15:0] din, 
    input [3:0] shift_amt,
    input [2:0] mode,
    output [15:0] dout
);
    
    //Modes of op
    localparam LSL = 3'b000;
    localparam LSR = 3'b001;
    localparam ASR = 3'b010;
    localparam ROL = 3'b011;
    localparam ROR = 3'b100;

    //Control and Padding Signal
    wire is_left = (mode == LSL) || (mode == ROL);
    wire is_rotate = (mode == ROL) || (mode == ROR);
    wire pad_bit = (mode == ASR) ? din[15] : 1'b0;

    //Pre-reverse the input(for left shift) so that only 1 shifter is instantiated
    wire [15:0] stage0_in;
    genvar i;
    generate
        for(i = 0; i < 16; i = i + 1) begin: gen_pre_rev
            assign stage0_in[i] = is_left ? din[15-i] : din[i];
        end
    endgenerate

    //Output after checking S[0]
    wire [15:0] stage0_out;
    assign stage0_out = shift_amt[0] ? {(is_rotate) ? stage0_in[0] : pad_bit, stage0_in[15:1]} 
                        : stage0_in;

    //Output after checking S[1]
    wire [15:0] stage1_out;
    assign stage1_out = shift_amt[1] ? {(is_rotate) ? stage0_out[1:0] : {2{pad_bit}}, stage0_out[15:2]}
                        : stage0_out;

    //Output after checking S[2]
    wire [15:0] stage2_out;
    assign stage2_out = shift_amt[2] ? {(is_rotate) ? stage1_out[3:0] : {4{pad_bit}}, stage1_out[15:4]}
                        : stage1_out;

    //Output after checking S[3]
    wire [15:0] stage3_out;
    assign stage3_out = shift_amt[3] ? {(is_rotate) ? stage2_out[7:0] : {8{pad_bit}}, stage2_out[15:8]}
                        : stage2_out;

    //Output bit reversal
    generate 
        for(i = 0; i < 16; i = i + 1) begin: gen_post_rev
            assign dout[i] = is_left ? stage3_out[15-i] : stage3_out[i];
        end
    endgenerate
endmodule