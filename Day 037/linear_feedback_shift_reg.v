// A Galois Architecture of a LFSR with the taps and width as parameters
module lfsr_galois#(parameter WIDTH = 4, parameter [WIDTH-1:0] TAPS = 4'b1000
)(
    input clk,
    input nreset,
    input enable,
    output [WIDTH-1:0]q
);

    reg [WIDTH-1:0] lfsr_reg;

    wire feedback = lfsr_reg[WIDTH-1];
    wire [WIDTH-1:0] mask = TAPS & {WIDTH{feedback}};

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            lfsr_reg <= 1'b1; //Other bits will be zero by default
        end
        else if(enable) begin
             lfsr_reg <= {lfsr_reg[WIDTH-2:0], feedback} ^ mask;
        end
        else lfsr_reg <= lfsr_reg;
    end

    assign q = lfsr_reg;
endmodule
