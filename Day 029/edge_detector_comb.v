// Detecting edges but the output are wires(avoids the 1-cycle evaluation delay for outputs but one cycle penalty due to shifting(to avoid metastability))

module edge_detector_combinational(input clk, nreset, signal, output rising_edge, falling_edge, same_level);
    reg [2:0] temp_store;
    wire signal_curr, signal_prev;
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            temp_store <= 3'b000;
        end
        else begin
            temp_store <= {temp_store[1:0], signal};
        end
    end
    assign signal_curr = temp_store[1];
    assign signal_prev = temp_store[2];
    assign rising_edge = (signal_curr && !signal_prev);
    assign same_level = (signal_curr == signal_prev);
    assign falling_edge = (!signal_curr && signal_prev);
endmodule
