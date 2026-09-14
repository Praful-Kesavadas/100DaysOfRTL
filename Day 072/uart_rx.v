module uart_rx #(
    parameter BAUD_RATE = 115_200,
    parameter CLK_FREQ = 50_000_000,
    parameter OVERSAMPLE = 16,
    parameter SAMPLING_FREQ = OVERSAMPLE*BAUD_RATE,
    parameter CLKS_PER_SAMPLE = CLK_FREQ/SAMPLING_FREQ
)(
    input clk, nreset,
    input rx_in,
    output reg [7:0] rx_data,
    output reg rx_valid, rx_busy, framing_error
);
    localparam WIDTH = $clog2(CLKS_PER_SAMPLE);

    //FSM States
    localparam S_IDLE = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA = 2'd2;
    localparam S_STOP = 2'd3;

    reg [1:0] state, next_state;

    //Synchronizer and edge detect
    reg rx_sync_s1, rx_sync, rx_sync_prev;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            rx_sync_s1 <= 1'b1;
            rx_sync <= 1'b1;
            rx_sync_prev <= 1'b1;
        end
        else begin
            rx_sync_s1 <= rx_in;
            rx_sync <= rx_sync_s1;
            rx_sync_prev <= rx_sync;  
        end
    end 

    //Baud Counter
    reg [WIDTH-1:0] clk_count;
    wire sample_tick = (clk_count == CLKS_PER_SAMPLE-1);

    always@(posedge clk or negedge nreset) begin
        if(!nreset) clk_count <= 0;
        else begin
            if(state == S_IDLE) clk_count <= 0;
            else if(sample_tick) clk_count <= 0;
            else clk_count <= clk_count + 1'b1;
        end
    end

    //Majority Voting for bit 
    reg [1:0] vote_samples;
    wire voted_bit = (vote_samples[0] & vote_samples[1]) |
                     (vote_samples[1] & rx_sync) |
                     (rx_sync & vote_samples[0]);
    //Falling edge detect
    wire rx_falling_edge = (rx_sync_prev == 1'b1) && (rx_sync == 1'b0);

    reg [3:0] sample_cnt;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;

    //State Transition
    always@(posedge clk or negedge nreset) begin
        if(!nreset) state <= S_IDLE;
        else state <= next_state;
    end

    //Next State Logic
    always@(*) begin
        next_state = state;
        case(state)
            S_IDLE: begin
                if(rx_falling_edge) next_state = S_START;
            end 
            S_START: begin
                if(sample_tick && sample_cnt == 4'd7) begin
                    if(voted_bit == 1'b0) next_state = S_DATA;
                    else next_state = S_IDLE;
                end
            end
            S_DATA: begin
                if(sample_tick && sample_cnt == 4'd15 && bit_idx == 3'd7) begin
                    next_state = S_STOP;
                end
            end
            S_STOP: begin
                if(sample_tick && sample_cnt == 4'd15) 
                    next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    //Register Updates
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            sample_cnt <= 4'd0;
            bit_idx <= 3'd0;
            shift_reg <= 8'd0;
            rx_data <= 8'b0;
            rx_valid <= 1'b0;
            framing_error <= 1'b0;
            vote_samples <= 2'b00;
        end
        else begin
            framing_error <= 1'b0;
            rx_valid <= 1'b0;
            case(state)
                S_IDLE: begin
                    sample_cnt <= 4'd0;
                    bit_idx <= 3'd0;
                    vote_samples <= 2'd0;
                end
                S_START: begin
                    if(sample_tick) begin
                        if(sample_cnt == 4'd5) vote_samples[0] <= rx_sync;
                        if(sample_cnt == 4'd6) vote_samples[1] <= rx_sync;

                        if(sample_cnt == 4'd7) sample_cnt <= 0;
                        else sample_cnt <= sample_cnt + 1'b1;
                    end
                end
                S_DATA: begin
                    if(sample_tick) begin
                        if(sample_cnt == 4'd13) vote_samples[0] <= rx_sync;
                        if(sample_cnt == 4'd14) vote_samples[1] <= rx_sync;
                        if(sample_cnt == 4'd15) begin
                            sample_cnt <= 4'd0;
                            shift_reg <= {voted_bit, shift_reg[7:1]};
                            bit_idx <= bit_idx + 1'b1;
                        end
                        else begin
                            sample_cnt <= sample_cnt + 1'b1;
                        end
                    end
                end
                S_STOP: begin
                    if(sample_tick) begin
                        if(sample_cnt == 4'd13) vote_samples[0] <= rx_sync;
                        if(sample_cnt == 4'd14) vote_samples[1] <= rx_sync;

                        if(sample_cnt == 4'd15) begin
                            sample_cnt <= 0;
                            if(voted_bit == 1'b1) begin
                                rx_data <= shift_reg;
                                rx_valid <= 1'b1;
                            end
                            else begin
                                framing_error <= 1'b1;
                            end
                        end
                        else sample_cnt <= sample_cnt + 1'b1;
                    end
                end
                default: begin
                    //Hold
                end
            endcase
        end
    end

    always@(*) begin
        rx_busy = (state != S_IDLE);
    end
endmodule