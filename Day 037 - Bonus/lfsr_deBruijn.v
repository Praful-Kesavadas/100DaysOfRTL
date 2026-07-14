module lfsr_deBruijn #(parameter TAPS = 4'b0001, parameter WIDTH = 4
)(
    input clk,
    input nreset,
    input enable,
    output [WIDTH-1:0] q
);

    reg [WIDTH-1:0] lfsr_reg;

    wire feedback;
    wire lookahead_wake;

    assign feedback = lfsr_reg[WIDTH-1];
    assign lookahead_wake = ~(|lfsr_reg[WIDTH-2:0]); // To avoid the locking of state after the all zero state which was forbidden in the Galois architecture

    wire active_feedback = feedback ^ lookahead_wake;
    wire [WIDTH-1:0] mask = TAPS & {WIDTH{active_feedback}};

    always@(posedge clk or negedge nreset) begin
        if(!nreset) lfsr_reg <= 1'b1;
        else if(enable) begin
            lfsr_reg <= {lfsr_reg[WIDTH-2:0], active_feedback} ^ mask;
        end
    end
    assign q = lfsr_reg;
endmodule
