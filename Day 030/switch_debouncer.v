// IDEA: An external mechanical switching might not result in a single pulse when it is translated into electrical signal. It might come out as 20-50 high-low
//       transitions. Hence a debouncer circuit is needed.
// 3 stages: - A CDC front gate (2 D-FlipFlops to avoid metastability)
//           - A state change detector to check whether the signal is stable or not
//           - A modulo-N counter to count till the target time during which the state shouldn't change. If it changes, then reset the counter again

module switch_debouncer#(parameter CLK_FREQUENCY = 100_000_000, DEBOUNCE_MS = 10)(input clk, nreset, signal_in, output reg signal_out);

    localparam MAXIMUM = (CLK_FREQUENCY * DEBOUNCE_MS)/1000;
    localparam WIDTH = $clog2(MAXIMUM);
    wire curr_state, prev_state;
    reg [2:0] temp_store;
    reg [WIDTH-1:0] count;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            signal_out <= 1'b0;
            count <= {WIDTH{1'b0}};
            temp_store <= 3'b000;
        end
        else begin
            temp_store <= {temp_store[1:0], signal_in};
                if(curr_state ^ prev_state) count <= {WIDTH{1'b0}};
                else if(count >= MAXIMUM - 1) begin
                    count <= count;
                    signal_out <= prev_state;
                end
                else count <= count + 1;
            end
    end
    assign curr_state = temp_store[1];
    assign prev_state = temp_store[2];
endmodule
