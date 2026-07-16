
module keypad_controller#(parameter FREQ_MHz = 50, DEBOUNCE_MS = 10
)(
    input clk, nreset, 
    input [3:0] col_in,
    output reg [3:0] row_out, 
    output reg [3:0] key_code,
    output reg key_valid
);

    // Generating enable signal for human friendly frequencies
    localparam MILLI_SEC_COUNTER = FREQ_MHz * 1000;
    localparam WIDTH_MILLI = $clog2(MILLI_SEC_COUNTER);
    reg [WIDTH_MILLI-1:0] milli_counter;
    reg enable;

    always @(posedge clk or negedge nreset) begin
        if(!nreset) begin
            milli_counter <= 0;
            enable <= 0;
        end
        else if(milli_counter >= MILLI_SEC_COUNTER - 1) begin
            milli_counter <= 0;
            enable <= 1'b1;
        end
        else begin
            milli_counter <= milli_counter + 1'b1;
            enable <= 1'b0;
        end
    end

    //To avoid metastability for the asynchronous col_in input
    wire [3:0] prev_state, curr_state;
    reg [11:0] col_in_shifter;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            col_in_shifter <= 12'hFFF; //Button press means the col will be pulled down to 0. Hence 1 implies no button press
        end
        else begin
            col_in_shifter <= {col_in_shifter[7:0], col_in};
        end 
    end
    assign prev_state = col_in_shifter[11:8];
    assign curr_state = col_in_shifter[7:4];

    //Debouncer Circuit
    localparam DEBOUNCE_COUNTER_MAX = FREQ_MHz * DEBOUNCE_MS * 1000;
    localparam WIDTH = $clog2(DEBOUNCE_COUNTER_MAX);
    reg [WIDTH-1:0] debounce_count;
    reg valid_key_press;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            debounce_count <= 0;
            valid_key_press <= 1'b0;
        end
        else begin
            if(curr_state == 4'b1111) begin
                debounce_count <= 0;
                valid_key_press <= 0;
            end
            else if(curr_state ^ prev_state) begin
                debounce_count <= 0;
                valid_key_press <= 1'b0;
            end
            else if(debounce_count >= DEBOUNCE_COUNTER_MAX - 1) begin
                debounce_count <= 0;
                valid_key_press <= 1'b1;
            end
            else begin
                debounce_count <= debounce_count + 1'b1;
                valid_key_press <= 1'b0;
            end
        end
    end

    //States for transition
    localparam IDLE = 3'd0;
    localparam ROW1 = 3'd1;
    localparam ROW2 = 3'd2;
    localparam ROW3 = 3'd3;
    localparam ROW4 = 3'd4;
    localparam FREEZE = 3'd5;

    //Next state logic
    reg [2:0] state, next_state;

    always@(*) begin
        next_state = state;
        case(state)
            IDLE: begin
                if(valid_key_press) next_state = ROW1;
                else next_state = IDLE;
            end
            ROW1: begin
                if(enable) begin
                    if(curr_state != 4'b1111) next_state = FREEZE;
                    else next_state = ROW2;
                end
            end
            ROW2: begin
                if(enable) begin
                    if(curr_state != 4'b1111) next_state = FREEZE;
                    else next_state = ROW3;
                end
            end
            ROW3: begin
                if(enable) begin
                    if(curr_state != 4'b1111) next_state = FREEZE;
                    else next_state = ROW4;
                end
            end
            ROW4: begin
                if(enable) begin
                    if(curr_state != 4'b1111) next_state = FREEZE;
                    else next_state = IDLE;
                end
            end
            FREEZE: begin
                if(curr_state == 4'b1111) next_state = IDLE;   // Stay in the same state unless the user takes his finger off the switch
            end
        endcase
    end

    //State Transition
    always@(posedge clk or negedge nreset) begin
        if(!nreset) state <= IDLE;
        else state <= next_state;
    end

    //Register Updates
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            key_valid <= 1'b0;
        end
        else begin
            key_valid <= (next_state == FREEZE & state != FREEZE);
        end
    end

    always@(*) begin
        case(state) 
            IDLE: row_out = 4'b0000; // To detect any button press
            ROW1: row_out = 4'b1110;
            ROW2: row_out = 4'b1101;
            ROW3: row_out = 4'b1011;
            ROW4: row_out = 4'b0111;
            FREEZE: row_out = 4'b0000;
            default: row_out = 4'b1111;
        endcase
    end 

    always@(posedge clk or negedge nreset) begin
        if(!nreset) key_code <= 4'h0;
        else if(next_state == FREEZE && state != FREEZE) begin
            case(state)
                ROW1: begin
                    case(curr_state)
                        4'b1110: key_code <= 4'h1; //{1,1} ({row, col})
                        4'b1101: key_code <= 4'h2; //{1,2}
                        4'b1011: key_code <= 4'h3; //{1,3}
                        4'b0111: key_code <= 4'hA; //{1,4}
                    endcase
                end
                ROW2: begin
                    case(curr_state)
                        4'b1110: key_code <= 4'h4; //{2,1}
                        4'b1101: key_code <= 4'h5; //{2,2}
                        4'b1011: key_code <= 4'h6; //{2,3}
                        4'b0111: key_code <= 4'hB; //{2,4}
                    endcase
                end
                ROW3: begin
                    case(curr_state)
                        4'b1110: key_code <= 4'h7; //{3,1}
                        4'b1101: key_code <= 4'h8; //{3,2}
                        4'b1011: key_code <= 4'h9; //{3,3}
                        4'b0111: key_code <= 4'hC; //{3,4}
                    endcase
                end 
                ROW4: begin
                    case(curr_state)
                        4'b1110: key_code <= 4'hE; //{4,1} (*)
                        4'b1101: key_code <= 4'h0; //{4,2}
                        4'b1011: key_code <= 4'hF; //{4,3} (#)
                        4'b0111: key_code <= 4'hD; //{4,4}
                    endcase
                end
            endcase
        end
    end
endmodule