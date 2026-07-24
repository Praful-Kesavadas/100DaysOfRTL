//Binary to BCD conversion using double dabble technique

module double_dabble_converter#(parameter WIDTH = 8
)(
    input clk, nreset, start,
    input [WIDTH-1:0] data_in,
    output [3:0] hundreds, tens, ones,
    output valid,
    output reg carry
);
    wire compute_done;

    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam DONE = 2'd2;

    reg [1:0] state, next_state;

    //Next State logic
    always@(*) begin
        next_state = state;
        case(state) 
            IDLE: begin
                if(start) next_state = COMPUTE;
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

    //Combinational Datapath logic
    localparam STORE_WIDTH = 12 + WIDTH;
    reg [STORE_WIDTH-1:0] store;
    reg [STORE_WIDTH-1:0] store_next;
    reg [3:0] hundreds_next, tens_next, ones_next;
    always@(*) begin
        {hundreds_next, tens_next, ones_next} = {hundreds, tens, ones};
        if(ones >= 5) ones_next = ones_next + 4'd3;
        if(tens >= 5) tens_next = tens_next + 4'd3;
        if(hundreds >= 5) hundreds_next = hundreds_next + 4'd3;

        {carry,store_next} = {1'b0, hundreds_next, tens_next, ones_next, store[WIDTH-1:0]} << 1;
    end
    

    //Synchronous updates
    reg [$clog2(WIDTH):0] count;
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            store <= 0;
            count <= 0;
        end
        else begin
            case(state) 
                IDLE: begin
                    if(start) begin
                        store <= {12'b0, data_in};
                        count <= 0;
                    end
                end
                COMPUTE: begin
                    count <= count + 1;
                    store <= store_next;
                end
                DONE: begin
                    count <= 0;
                end
            endcase
        end
    end

    //Output assigns
    assign compute_done = (count == WIDTH - 1);
    assign hundreds = store[WIDTH+11:WIDTH+8];
    assign tens = store[WIDTH+7: WIDTH+4];
    assign ones = store[WIDTH+3: WIDTH];
    assign valid = (state == DONE);
endmodule