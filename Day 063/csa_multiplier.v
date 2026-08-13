module csa_multiplier#(parameter DATA_WIDTH = 16
)(
    input clk, nreset,
    input start,
    input [DATA_WIDTH-1:0] A, B,
    output reg [2*DATA_WIDTH-1:0] result,
    output reg valid
);
    localparam PROD_WIDTH = 2 * DATA_WIDTH;

    reg [DATA_WIDTH-1:0] A_reg, B_reg;
    reg valid_reg;

    //2D wire arrays for stage by stage reduction
    wire [PROD_WIDTH-1:0] PP [0:DATA_WIDTH-1]; //Shifted Partial Products
    wire [PROD_WIDTH-1:0] S [0:DATA_WIDTH-1]; // Sum vectors
    wire [PROD_WIDTH:0] C [0:DATA_WIDTH-1]; //Carry vector(1 bit wider)

    wire [PROD_WIDTH-1:0] csa_comb_result;

    //Input Latching
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            A_reg <= {DATA_WIDTH{1'b0}};
            B_reg <= {DATA_WIDTH{1'b0}};
            valid_reg <= 0;
        end
        else begin
            valid_reg <= start;
            if(start) begin
                A_reg <= A;
                B_reg <= B;
            end
        end
    end

    //CSA Reduction logic
    genvar r, k;

    generate
        for(r = 0; r < DATA_WIDTH; r = r + 1) begin: gen_partial_products
            assign PP[r] = {{(DATA_WIDTH){1'b0}}, (A_reg & {DATA_WIDTH{B_reg[r]}})} << r;
        end
    endgenerate

    assign S[0] = PP[0];
    assign C[0] = {(PROD_WIDTH+1){1'b0}};

    generate
        for(r = 1; r < DATA_WIDTH; r = r + 1)begin: gen_csa_stages
            assign C[r][0] = 1'b0;
            for(k = 0; k < PROD_WIDTH; k = k + 1) begin: gen_fa_row
                full_adder fa_inst(
                    .a(S[r-1][k]),
                    .b(C[r-1][k]),
                    .carry_in(PP[r][k]),
                    .carry_out(C[r][k+1]),
                    .sum(S[r][k])
                );
            end
        end
    endgenerate

    assign csa_comb_result = S[DATA_WIDTH-1] + C[DATA_WIDTH-1][PROD_WIDTH-1:0];

    //Output Latching
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            result <= {PROD_WIDTH{1'b0}};
            valid <= 1'b0;
        end
        else begin
            valid <= valid_reg;
            if(valid_reg) begin
                result <= csa_comb_result;
            end
        end
    end
endmodule
