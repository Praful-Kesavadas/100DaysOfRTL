module restoring_divider#(parameter WIDTH = 4
)(
    input clk, nreset, start,
    input [WIDTH-1:0] dividend, divisor,
    output [WIDTH-1:0] quotient,
    output [WIDTH-1:0] remainder,
    output div_by_zero,
    output valid
);

    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam DONE = 2'd2;

    reg [1:0] state, next_state;

    //Next State Logic
    always@(*) begin
        next_state = state;
        case(state) 
            IDLE: begin
                if(start) begin
                    if(dividend == 0 | divisor == 0) next_state = DONE;
                    else next_state = COMPUTE;
                end 
            end
            COMPUTE: if(compute_done) next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    //State Transition
    always@(posedge clk or negedge nreset) begin
        if(!nreset) state <= IDLE;
        else state <= next_state;
    end
    
    //Combinational Datapath Block
    reg [2*WIDTH-1:0] vector;
    reg [2*WIDTH-1:0] shifted_vec;
    reg [WIDTH:0] trial_sub;
    wire [2*WIDTH-1:0] raw_left_shift;

    assign raw_left_shift = {vector[2*WIDTH-2:0], 1'b0};
    always@(*) begin
        trial_sub = {1'b0, raw_left_shift[2*WIDTH-1:WIDTH]} - {1'b0, divisor};
        case(trial_sub[WIDTH]) //Borrow bit: If 0 -> successful subtraction, else unsuccessful
            1'b0: begin
                shifted_vec = {trial_sub[WIDTH-1:0], raw_left_shift[WIDTH-1:1], 1'b1};
            end
            1'b1: begin
                shifted_vec = raw_left_shift;
            end
        endcase
    end

    //Synchronous Register Updates
    reg [$clog2(WIDTH):0] count;
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            count <= 0;
            vector <= 0;
        end
        else begin
            case(state) 
                IDLE: begin
                    if(start) begin
                        vector <= {{WIDTH{1'b0}}, dividend};
                        count <= 0;
                    end
                end
                COMPUTE: begin
                    vector <= shifted_vec;
                    count <= count + 1;
                end
                DONE: begin
                    count <= 0;
                end
            endcase
        end
    end

    assign compute_done = (count == WIDTH - 1);
    assign valid = (state == DONE);
    assign div_by_zero = (state == DONE && divisor == 0);

    assign quotient = (divisor == 0) ? {WIDTH{1'b1}}:
                      (dividend == 0) ? {WIDTH{1'b0}}:
                      vector[WIDTH-1:0];
    assign remainder = (divisor == 0) ? {WIDTH{1'b0}}:
                       (dividend == 0) ? {WIDTH{1'b0}}:
                       vector[2*WIDTH-1:WIDTH];
endmodule