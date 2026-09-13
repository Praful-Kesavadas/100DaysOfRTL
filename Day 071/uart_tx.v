module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115_200,
    parameter CLKS_PER_BIT = CLK_FREQ/BAUD_RATE
)(
    input clk, nreset,
    input tx_start,
    input [7:0] d_in,
    output reg tx_serial,
    output reg tx_busy,
    output reg tx_done
);

    localparam CNT_WIDTH = $clog2(CLKS_PER_BIT);

    //FSM States
    localparam S_IDLE = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA = 2'd2;
    localparam S_STOP = 2'd3;

    reg [1:0] state, next_state;

    reg [2:0] bit_idx;
    reg [7:0] tx_shift_reg;

    //Baud Counter
    reg [CNT_WIDTH-1:0] count;
    wire baud_tick = (count == (CLKS_PER_BIT-1));

    always@(posedge clk or negedge nreset) begin
        if(!nreset) count <= 0;
        else begin
            if(state == S_IDLE) count <= 0;
            else if(baud_tick) count <= 0;
            else count <= count + 1'b1;
        end
    end

    //State Transition
    always@(posedge clk or negedge nreset) begin
        if(!nreset) state <= S_IDLE;
        else state <= next_state;
    end 

    //Next State Logic
    always@(*) begin
        next_state = state;
        case(state)
            S_IDLE: if(tx_start) next_state = S_START;
            S_START: if(baud_tick) next_state = S_DATA;
            S_DATA: if(baud_tick && bit_idx == 3'd7) next_state = S_STOP;
            S_STOP: if(baud_tick) next_state = S_IDLE;
            default: next_state = S_IDLE;
        endcase
    end

    //Register updates
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            tx_serial <= 1'b1; //Stay High in MARK state
            bit_idx <= 3'd0;
            tx_shift_reg <= 8'd0;
            tx_done <= 1'b0;
        end
        else begin
            tx_done <= 0;
            case(state)
                S_IDLE: begin
                    tx_serial <= 1'b1;
                    bit_idx <= 3'd0;
                    if(tx_start) tx_shift_reg <= d_in;
                end
                S_START: begin
                    tx_serial <= 1'b0;
                    bit_idx <= 3'd0;
                end
                S_DATA: begin
                    tx_serial <= tx_shift_reg[0];
                    if(baud_tick) begin
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        bit_idx <= bit_idx + 1'b1;
                    end
                end
                S_STOP: begin
                    tx_serial <= 1'b1;
                    if(baud_tick) tx_done <= 1'b1;
                end
                default: tx_serial <= 1'b1;
            endcase
        end
    end
    always@(*) begin
        tx_busy = (state != S_IDLE);
    end
endmodule