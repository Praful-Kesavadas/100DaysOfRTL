module serial_frame_parity(
    input clk, nreset, data_valid,
    input parity_mode, //0 for even parity mode, 1 for odd parity mode
    input frame_start, frame_end,
    input serial_bit_in,
    output reg parity_error,
    output reg parity_valid
);
    reg accumulator; 
    wire accumulator_next = frame_start ? serial_bit_in : (accumulator ^ serial_bit_in);
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            accumulator <= 1'b0;
            parity_error <= 1'b0;
            parity_valid <= 1'b0;
        end
        else begin
            parity_valid <= 0;
            if(data_valid) begin accumulator <= accumulator_next;
                if(frame_end) begin
                    parity_error <= accumulator_next ^ parity_mode;
                    parity_valid <= 1'b1;
                end
            end
        end
    end
endmodule
