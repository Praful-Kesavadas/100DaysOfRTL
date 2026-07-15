module quadrature_encoder_decoder(
    input clk, nreset,
    input [1:0] mode,
    input phaseA, phaseB,
    output reg clockwise, anticlockwise, error
);

    reg [2:0] phaseA_shifter, phaseB_shifter;

    // A CDC synchronizer
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            phaseA_shifter <= 3'b000;
            phaseB_shifter <= 3'b000;
        end
        else begin
            phaseA_shifter <= {phaseA_shifter[1:0], phaseA};
            phaseB_shifter <= {phaseB_shifter[1:0], phaseB};
        end
    end
    wire curr_A = phaseA_shifter[1];
    wire prev_A = phaseA_shifter[2];
    wire curr_B = phaseB_shifter[1];
    wire prev_B = phaseB_shifter[2];

    reg change;
    always@(*) begin
        case(mode)
            2'b01: change = (curr_A & ~prev_A);
            2'b10: change = (curr_A != prev_A);
            2'b11: change = (curr_A != prev_A) | (curr_B != prev_B);
            default: change = (curr_A != prev_A) || (curr_B != prev_B);
        endcase
    end

    //Register change logic
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            clockwise <= 0;
            anticlockwise <= 0;
            error <= 0;
        end
        else begin
            clockwise <= 0;
            anticlockwise <= 0;
            error <= 0;
            if(change) begin
                clockwise <= (~(prev_A | prev_B | curr_B) & curr_A) | (~prev_B & prev_A & curr_A & curr_B) | (prev_B & prev_A & curr_B & ~curr_A) | (prev_B & ~(prev_A | curr_A | curr_B));
                anticlockwise <= (~(prev_B | prev_A | curr_A) & curr_B) | (~(prev_B | curr_A | curr_B) & prev_A) | (prev_B & prev_A & curr_A & ~curr_B) | (prev_B & ~prev_A & curr_A & curr_B);
                error <= (~(prev_A | prev_B) & curr_A & curr_B) | (~(prev_B | curr_A) & prev_A & curr_B) | (~(curr_A | curr_B) & prev_A & prev_B) | (~(prev_A | curr_B) & prev_B & curr_A);
            end
        end
    end
    
endmodule
