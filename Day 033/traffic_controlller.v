// Output is One-hot encoding: [RED YELLOW GREEN]
module traffic_controller#(parameter YELLOW_CYCLE = 3, parameter RED_CYCLE = 20)(input clk, nreset, output reg [2:0] NS_light, EW_light);

    localparam IDLE = 3'd0;
    localparam NS_GREEN_EW_RED = 3'd1;
    localparam NS_YELLOW_EW_RED = 3'd2;
    localparam NS_RED_EW_GREEN = 3'd3;
    localparam NS_RED_EW_YELLOW = 3'd4;

    localparam WIDTH_RED = $clog2(RED_CYCLE);

    reg [2:0] state, next_state;
    reg [WIDTH_RED-1:0] red_counter;

    always@(*) begin
        next_state = state;
        case(state)
            IDLE: next_state = NS_GREEN_EW_RED;
            NS_GREEN_EW_RED:  next_state = (red_counter == RED_CYCLE - YELLOW_CYCLE - 1) ? NS_YELLOW_EW_RED : NS_GREEN_EW_RED;
            NS_YELLOW_EW_RED: next_state = (red_counter == RED_CYCLE - 1) ? NS_RED_EW_GREEN : NS_YELLOW_EW_RED;
            NS_RED_EW_GREEN: next_state = (red_counter == RED_CYCLE - YELLOW_CYCLE - 1) ? NS_RED_EW_YELLOW : NS_RED_EW_GREEN;
            NS_RED_EW_YELLOW: next_state = (red_counter == RED_CYCLE - 1) ? NS_GREEN_EW_RED : NS_RED_EW_YELLOW;
            default: next_state = IDLE;
        endcase
    end

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            red_counter <= {WIDTH_RED{1'b0}};
            state <= IDLE;
        end
        else begin
            state <= next_state;
            if((state == NS_YELLOW_EW_RED && next_state == NS_RED_EW_GREEN) || (state == NS_RED_EW_YELLOW && next_state == NS_GREEN_EW_RED) || state == IDLE) begin
                red_counter <= {WIDTH_RED{1'b0}};
            end
            else red_counter <= red_counter + 1'b1;
        end
    end

    always@(*) begin
        case(state)
            NS_GREEN_EW_RED: begin
                NS_light = 3'b001;
                EW_light = 3'b100;
            end
            NS_YELLOW_EW_RED: begin
                NS_light = 3'b010;
                EW_light = 3'b100;
            end
            NS_RED_EW_GREEN: begin
                NS_light = 3'b100;
                EW_light = 3'b001;
            end
            NS_RED_EW_YELLOW: begin
                NS_light = 3'b100;
                EW_light = 3'b010;
            end
            default: {NS_light, EW_light} = 6'b100100;
        endcase
    end
endmodule
