module booth_multiplier#(parameter WIDTH = 4
)(
    input clk, nreset, start,
    input [WIDTH-1:0] A, B,
    output [2*WIDTH-1:0] result,
    output valid
);
    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam DONE = 2'd2;

    reg [$clog2(WIDTH):0] count;

    reg [1:0] state, next_state;
    wire compute_done;

    //Next state logic
    always@(*) begin
        next_state = state;
        case(state) 
            IDLE: begin
                if(start) next_state = COMPUTE;
            end
            COMPUTE: begin
                if(compute_done) next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    //State transition
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            state <= IDLE;
        end
        else state <= next_state;
    end

    //Datapath combinational logic
    reg [2*WIDTH:0] booth_reg;
    reg [WIDTH-1:0] next_A;
    reg [2*WIDTH:0] shifted_vec;
    always@(*) begin
        next_A = booth_reg[2*WIDTH : WIDTH+1];

        case({booth_reg[1:0]})
            2'b01: next_A = booth_reg[2*WIDTH: WIDTH+1] + A;
            2'b10: next_A = booth_reg[2*WIDTH: WIDTH+1] - A;
            default: next_A = booth_reg[2*WIDTH: WIDTH+1];
        endcase

        shifted_vec = {next_A[WIDTH-1], next_A, booth_reg[WIDTH:1]};
    end
    
    //Synchronous Register Updates
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            count <= 0;
            booth_reg <= 0;
        end
        else begin
            case(state)
                IDLE: begin
                    if(start) begin
                        booth_reg[2*WIDTH: WIDTH+1] <= 0;
                        booth_reg[WIDTH:1] <= B;
                        booth_reg[0] <= 1'b0;
                        count <= 0;
                    end
                end
                COMPUTE: begin
                    booth_reg <= shifted_vec;
                    count <= count + 1;
                end
                DONE: begin
                    count <= 0;
                end
            endcase
        end
    end
    //Combinational flag assigning
    assign compute_done = (count == WIDTH - 1);
    assign valid = (state == DONE);
    assign result = booth_reg[2*WIDTH:1];
endmodule