module non_restoring_divider#(parameter WIDTH = 4
)(
    input clk, nreset, start,
    input [WIDTH-1:0] dividend, divisor,
    output [WIDTH-1:0] quotient,
    output [WIDTH:0] remainder,
    output div_by_zero, valid
);
    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam DONE = 2'd2;

    reg [1:0] state, next_state;

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

    always@(posedge clk or negedge nreset) begin
        if(!nreset) state <= IDLE;
        else state <= next_state;
    end

    //Combinational Datapath Block
    reg [2*WIDTH:0] vector;
    reg [WIDTH:0] A_new;
    wire [2*WIDTH:0] raw_left_shift;
    reg [2*WIDTH:0] shifted_vec;

    assign raw_left_shift = {vector[2*WIDTH-1:0], 1'b0};

    wire current_sign = vector[2*WIDTH];
    always@(*) begin
        if(current_sign) begin  // Previous accum was negative, hence add the divisor for the next cycle
            A_new = raw_left_shift[2*WIDTH:WIDTH] + {1'b0, divisor};
        end
        else begin 
            A_new = raw_left_shift[2*WIDTH:WIDTH] - {1'b0, divisor};
        end

        shifted_vec = {A_new, raw_left_shift[WIDTH-1:1], !A_new[WIDTH]};
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
                        count <= 0;
                        vector <= {{(WIDTH+1){1'b0}}, dividend};
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

    // Output assignments
    assign compute_done = (count == WIDTH - 1);
    assign div_by_zero = (state == DONE && divisor == 0);
    assign valid = (state == DONE);

    assign quotient = (divisor == 0) ? {WIDTH{1'b1}}:
                      (dividend == 0) ? {WIDTH{1'b0}}:
                      vector[WIDTH-1:0];
    assign remainder = (divisor == 0) ? {(WIDTH+1){1'b0}}:
                       (dividend == 0) ? {(WIDTH+1){1'b0}}:
                       (vector[2*WIDTH]) ? ({vector[2*WIDTH:WIDTH]} + {1'b0, divisor}):
                       vector[2*WIDTH:WIDTH];
endmodule