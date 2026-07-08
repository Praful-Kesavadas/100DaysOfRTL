// To detect the sequence 1011 with overlapping digits allowed
module seq_detector_overlapping(input clk, nreset, in, output detected);
    localparam S0 = 3'd0;
    localparam S1 = 3'd1;
    localparam S2 = 3'd2;
    localparam S3 = 3'd3;
    localparam S4 = 3'd4;

    reg [2:0] state, next_state;

    //Next State Logic
    always@(*) begin
        next_state = state;
        case(state)
            S0: begin
                next_state = (in) ? S1 : S0;
            end
            S1: begin
                next_state = (in) ? S1 : S2;
            end
            S2: begin
                next_state = (in) ? S3 : S0;
            end
            S3: begin
                next_state = (in) ? S4 : S2;
            end
            S4: begin
                next_state = (in) ? S1 : S2;
            end
            default: next_state = S0;
        endcase
    end 
    //State change logic
    always @(posedge clk or negedge nreset) begin
        if(!nreset) begin
            state <= S0;
        end
        else begin
            state <= next_state;
        end
    end
    assign detected = (state == S4);
endmodule
