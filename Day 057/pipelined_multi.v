module pipelined_multiplier#(parameter WIDTH = 8
)(
    input clk, nreset,
    input valid_in,
    input [WIDTH-1:0] a, b,
    output reg [2*WIDTH-1:0] product,
    output reg valid_out
);
    localparam HALF = WIDTH/2;
    
    wire [HALF-1:0] a_L = a[HALF-1:0];
    wire [HALF-1:0] a_H = a[WIDTH-1:HALF];
    wire [HALF-1:0] b_L = b[HALF-1:0];
    wire [HALF-1:0] b_H = b[WIDTH-1:HALF];
    
    //Stage 1(partial products)
    reg [WIDTH-1:0] p0_reg;
    reg [WIDTH-1:0] p1_reg;
    reg [WIDTH-1:0] p2_reg;
    reg [WIDTH-1:0] p3_reg;

    reg valid_int;

    //Stage 1
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            {p0_reg, p1_reg, p2_reg, p3_reg} <= 0;
            valid_int <= 0;
        end
        else begin
            valid_int <= valid_in;
            if(valid_in) begin
                p0_reg <= a_L * b_L;
                p1_reg <= a_L * b_H;
                p2_reg <= a_H * b_L;
                p3_reg <= a_H * b_H;
            end
        end
    end

    //Stage 2
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            product <= 0;
            valid_out <= 0;
        end
        else begin
            valid_out <= valid_int;
            if(valid_int) begin
                product <= p0_reg + ({{WIDTH{1'b0}}, p1_reg} << HALF) + ({{WIDTH{1'b0}}, p2_reg}<< HALF) + ({{WIDTH{1'b0}}, p3_reg} << WIDTH); 
            end
        end
    end
endmodule

/* Relies on the eda tool to do the optimization, but this will be decoded as a 2 stage pipelined multiplier too
always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            valid_out <= 0;
            valid_int <= 0;
            p_reg <= 0;
            product <= 0;
        end
        else begin
           valid_int <= valid_in;
           valid_out <= valid_int;

           p_reg <= a * b;
           product <= p_reg;
        end
    end
*/