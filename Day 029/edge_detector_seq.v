// To detect the rising or falling edge of a signal

module edge_detector_seqential(input clk, nreset, signal, output reg falling_edge, rising_edge, same_level);
    reg signal_prev;
    reg signal_curr;
    
    always @(posedge clk or negedge nreset) begin
        if(!nreset) begin
            {falling_edge, rising_edge, same_level, signal_prev, signal_curr} <= 5'b00000;
        end
        else begin
            signal_curr <= signal;
            signal_prev <= signal_curr;
            if(signal_prev == signal_curr) {falling_edge, rising_edge, same_level} <= 3'b001;
            else if((signal_prev == 1'b1) && (signal_curr == 1'b0)) {falling_edge, rising_edge, same_level} <= 3'b100;
            else if((signal_prev == 1'b0) && (signal_curr == 1'b1)) {falling_edge, rising_edge, same_level} <= 3'b010;
        end
    end
endmodule
