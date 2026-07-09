module seq_detector_nonoverlapping(input clk, nreset, in, output detected);
    localparam S0 = 2'd0;
    localparam S1 = 2'd1;
    localparam S2 = 2'd2;
    localparam S3 = 2'd3;

    reg [1:0] state, next_state;

    always@(*)begin
        next_state = state;
        case(state)
            S0: begin
                next_state = in ? S1 : S0;
            end
            S1: begin
                next_state = in ? S1 : S2;
            end
            S2: begin
                next_state = in ? S3 : S0;
            end
            S3: begin
                next_state = S0;
            end
            default: next_state = S0;
        endcase
    end

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            state <= S0;
        end
        else begin
            state <= next_state;
        end
    end

    assign detected = (state == S3) && (in == 1'b1);
endmodule


/* To avoid any noise to affect the state. This will introduce robustness to noise with a penalty of 1 cycle evaluation delay
always @(posedge clk or negedge nreset) begin
    if (!nreset) begin
        detected_reg <= 1'b0;
    end else begin
        detected_reg <= (state == S3) && (in == 1'b1);
    end
end
*/
