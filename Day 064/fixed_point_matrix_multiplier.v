module fixed_point_matrix_multiplier#(parameter DATA_WIDTH = 16, parameter FRAC_WIDTH = 8
)(
    input clk, nreset, start,
    input signed [DATA_WIDTH-1:0] a00, a01, a10, a11, b00, b01, b10, b11,
    output reg signed[DATA_WIDTH-1:0] c00, c01, c10, c11,
    output reg valid
);  
    reg signed [DATA_WIDTH-1:0] a00_reg, a01_reg, a10_reg, a11_reg, b00_reg, b01_reg, b10_reg, b11_reg;
    reg valid_reg;
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            valid_reg <= 0;
            {a00_reg, a01_reg, a10_reg, a11_reg, b00_reg, b01_reg, b10_reg, b11_reg} <= 0;
        end
        else begin
            valid_reg <= start;
            if(start) begin
                a00_reg <= a00;
                a01_reg <= a01;
                a10_reg <= a10;
                a11_reg <= a11;
                b00_reg <= b00;
                b01_reg <= b01;
                b10_reg <= b10;
                b11_reg <= b11;
            end
        end
    end
    wire signed [2*DATA_WIDTH-1:0] prod [0:7];
    assign prod[0] = $signed(a00_reg) * $signed(b00_reg);
    assign prod[1] = $signed(a01_reg) * $signed(b10_reg);
    assign prod[2] = $signed(a00_reg) * $signed(b01_reg);
    assign prod[3] = $signed(a01_reg) * $signed(b11_reg);
    assign prod[4] = $signed(a10_reg) * $signed(b00_reg);
    assign prod[5] = $signed(a11_reg) * $signed(b10_reg);
    assign prod[6] = $signed(a10_reg) * $signed(b01_reg);
    assign prod[7] = $signed(a11_reg) * $signed(b11_reg);

    wire signed [2*DATA_WIDTH:0] sum [0:3];
    assign sum[0] = prod[0] + prod[1];
    assign sum[1] = prod[2] + prod[3];
    assign sum[2] = prod[4] + prod[5];
    assign sum[3] = prod[6] + prod[7];

    wire [DATA_WIDTH-1:0] c00_int, c01_int, c10_int, c11_int;
    assign c00_int = sum[0][DATA_WIDTH + FRAC_WIDTH - 1: FRAC_WIDTH];
    assign c01_int = sum[1][DATA_WIDTH + FRAC_WIDTH - 1:FRAC_WIDTH];
    assign c10_int = sum[2][DATA_WIDTH + FRAC_WIDTH - 1:FRAC_WIDTH];
    assign c11_int = sum[3][DATA_WIDTH + FRAC_WIDTH - 1:FRAC_WIDTH];

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            valid <= 0;
            {c00, c01, c10, c11} <= 0;
        end
        else begin
            valid <= valid_reg;
            c00 <= c00_int;
            c01 <= c01_int;
            c10 <= c10_int;
            c11 <= c11_int;
        end
    end
endmodule