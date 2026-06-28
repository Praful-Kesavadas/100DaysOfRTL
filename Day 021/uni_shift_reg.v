// A shift register having 4 modes of operation: Right shift, left shift, parallel load and memory/hold
// Mode: 00 -> no change, 01 -> Shift right, 10 -> Shift left, 11 -> Parallel load

module uni_shift_reg(input clk, nreset, serial_in_ls, serial_in_rs, input[3:0] parallel_load, input [1:0] mode, output reg [3:0] q);
    always@(posedge clk or negedge nreset) begin
        if(!nreset) q <= 4'b0000;
        else begin
            case(mode)
                2'b00: q <= q;
                2'b01: q <= {serial_in_rs, q[3:1]};
                2'b10: q <= {q[2:0], serial_in_ls};
                2'b11: q <= parallel_load;
                default: q <= q;
            endcase
        end
    end
endmodule
