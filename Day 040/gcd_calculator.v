// A GCD calculator making use of Euclidean Subtraction Algorithm(2 numbers A and B, iterative subtraction of smaller from larger until they are equal)

module gcd_calculator#(parameter WIDTH = 4
)(
    input [WIDTH-1:0] A, B,
    input clk, nreset,
    input start,
    output reg [WIDTH-1:0] gcd,
    output reg valid
);
    reg [WIDTH-1:0] reg_A, reg_B;
    wire compute_done;

    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam DONE = 2'd2;

    reg [1:0] state, next_state;

    //Next state logic
    always@(*) begin
        next_state = state;
        case(state)
            IDLE: begin
                if(start) begin
                    if(A == 0 || B == 0) next_state = DONE;
                    else next_state = COMPUTE;
                end
            end 
            COMPUTE: begin
                if(compute_done) next_state = DONE;
            end
            DONE: next_state = IDLE;
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

    // Register updates
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            reg_A <= 0;
            reg_B <= 0;
            gcd <= 0;
            valid <= 0;
        end
        else begin
            case(state) 
                IDLE: begin
                    valid <= 0;
                    if(start) begin
                        reg_A <= A;
                        reg_B <= B;
                    end
                end
                COMPUTE: begin
                    valid <= 0;
                    if(reg_A < reg_B) begin
                        reg_B <= reg_B - reg_A;
                    end
                    else if(reg_A > reg_B) begin
                        reg_A <= reg_A - reg_B;
                    end
                end
                DONE: begin
                    if(reg_A == 0 || reg_B == 0) begin
                        gcd <= (reg_A == 0) ? reg_B : reg_A; //GCD of (0,X) = X
                    end
                    else gcd <= reg_A;
                    valid <= 1'b1;
                end
            endcase
        end
    end
    assign compute_done = (reg_A == reg_B);
endmodule
