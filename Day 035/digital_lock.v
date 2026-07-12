module digital_lock(input clk, nreset, done_in, admin_reset_signal, passcode_in, input [3:0] pin_in, input [3:0] passcode, output reg [1:0] tries_left, output reg lock_open);

    //States
    localparam INPUT_PIN = 3'd0;
    localparam ONE_FAIL = 3'd1;
    localparam TWO_FAIL = 3'd2;
    localparam INACTIVE = 3'd3;
    localparam RESET_PIN = 3'd4;
    localparam SUCCESS = 3'd5;

    reg [3:0] correct_pin;
    reg [2:0] state, next_state;

    wire success, pin_reset_success;
    assign pin_reset_success = (state == RESET_PIN) && passcode_in;
    
    assign success = (pin_in == correct_pin);

    reg done_r;
    wire done_pulse;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) done_r <= 1'b0;
        else done_r <= done_in;
    end
    assign done_pulse = done_in && !done_r;

    // Next state logic
    always@(*) begin
        next_state = state;
        case(state) 
            INPUT_PIN: begin 
                if(admin_reset_signal) next_state = RESET_PIN;
                else if(done_pulse) next_state = success ? SUCCESS : ONE_FAIL;
            end
            ONE_FAIL: begin 
                if(admin_reset_signal) next_state = RESET_PIN;
                else if(done_pulse) next_state = success ? SUCCESS : TWO_FAIL;
            end
            TWO_FAIL: begin 
                if(admin_reset_signal) next_state = RESET_PIN;
                else if(done_pulse) next_state = success ? SUCCESS : INACTIVE;
            end
            INACTIVE: next_state = admin_reset_signal ? RESET_PIN : INACTIVE;
            RESET_PIN: next_state = pin_reset_success ? INPUT_PIN : RESET_PIN;
            SUCCESS: begin
                if(admin_reset_signal) next_state = RESET_PIN;
                else if(done_pulse) next_state = INPUT_PIN;
            end
            default: next_state = INPUT_PIN;
        endcase
    end

    //State Change
    always@(posedge clk or negedge nreset) begin
        if(!nreset) state <= INPUT_PIN;
        else state <= next_state;
    end

    //Register Updates
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            tries_left <= 2'd3;
            lock_open <= 1'b0;
            correct_pin <= 4'b0000; //Default to 4'b0000
        end
        else begin
            case(state)
                INPUT_PIN: begin 
                    tries_left <= 2'd3;
                    lock_open <= 1'b0;
                end
                ONE_FAIL: begin
                    tries_left <= 2'd2;
                    lock_open <= 1'b0;
                end
                TWO_FAIL: begin
                    tries_left <= 2'd1;
                    lock_open <= 1'b0;
                end
                INACTIVE: begin
                    tries_left <= 2'd0;
                    lock_open <= 1'b0;
                end 
                RESET_PIN: begin
                    if(pin_reset_success) correct_pin <= passcode;
                end
                SUCCESS: begin
                    tries_left <= 2'd3;
                    lock_open <= 1'b1;
                end
            endcase
        end
    end
endmodule