//CORDIC rotation mode using Q2.14 format
module cordic_rotation#(parameter DATA_WIDTH = 16, parameter ITERATIONS = 16
)(
    input clk, nreset, start,
    input [DATA_WIDTH-1:0] x_in, y_in, theta_in,
    output [DATA_WIDTH-1:0] x_out, y_out,
    output valid
);
    localparam signed [DATA_WIDTH-1:0] CORDIC_1_K = 16'sd9949;

    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam DONE = 2'd2;

    reg [1:0] state, next_state;
    reg [$clog2(ITERATIONS):0] i; //Iteration loop counter

    localparam EXT_WIDTH = DATA_WIDTH + 2; 
    reg signed [EXT_WIDTH-1:0] x_reg, y_reg, z_reg;
    reg signed [EXT_WIDTH-1:0] lut_angle;

    //To prevent the truncation
    wire signed [31:0] x_in_32 = {{16{x_in[DATA_WIDTH-1]}}, x_in};
    wire signed [31:0] y_in_32 = {{16{y_in[DATA_WIDTH-1]}}, y_in};
    wire signed [31:0] k_32    = {{16{CORDIC_1_K[DATA_WIDTH-1]}}, CORDIC_1_K};

    //Prescaling of the inputs
    wire signed [2*DATA_WIDTH-1:0] x_prescaled = (x_in_32 * CORDIC_1_K) >>> 14;
    wire signed [2*DATA_WIDTH-1:0] y_prescaled = (y_in_32 * CORDIC_1_K) >>> 14;

    always @(*) begin
        case (i)
            4'd0:  lut_angle = 16'sd12868; // arctan(2^-0) = 45.000 deg
            4'd1:  lut_angle = 16'sd7596;  // arctan(2^-1) = 26.565 deg
            4'd2:  lut_angle = 16'sd4014;  // arctan(2^-2) = 14.036 deg
            4'd3:  lut_angle = 16'sd2037;  // arctan(2^-3) = 7.125 deg
            4'd4:  lut_angle = 16'sd1023;  // arctan(2^-4) = 3.576 deg
            4'd5:  lut_angle = 16'sd512;   // arctan(2^-5) = 1.790 deg
            4'd6:  lut_angle = 16'sd256;   // arctan(2^-6) = 0.895 deg
            4'd7:  lut_angle = 16'sd128;   // arctan(2^-7) = 0.448 deg
            4'd8:  lut_angle = 16'sd64;    // arctan(2^-8) = 0.224 deg
            4'd9:  lut_angle = 16'sd32;    // arctan(2^-9)
            4'd10: lut_angle = 16'sd16;    // arctan(2^-10)
            4'd11: lut_angle = 16'sd8;     // arctan(2^-11)
            4'd12: lut_angle = 16'sd4;     // arctan(2^-12)
            4'd13: lut_angle = 16'sd2;     // arctan(2^-13)
            4'd14: lut_angle = 16'sd1;     // arctan(2^-14)
            4'd15: lut_angle = 16'sd1;
            default: lut_angle = 16'sd0;
        endcase
    end

    //Next state logic
    always@(*) begin
        next_state = state;
        case(state)
            IDLE: if(start) next_state = COMPUTE;
            COMPUTE: if(i == ITERATIONS - 1) next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    //State Transition
    always@(posedge clk or negedge nreset) begin
        if(!nreset) state <= IDLE;
        else state <= next_state;
    end

    /* //Block used for debugging
    always @(posedge clk) begin
    if (state == IDLE && start)
        $display("[LOAD] t=%0t x_in=%0d y_in=%0d theta_in=%0d | x_prescaled=%0d y_prescaled=%0d", 
                  $time, x_in, y_in, theta_in, x_prescaled, y_prescaled);
    end
    */
    
    //Synchronous updates
    wire signed [EXT_WIDTH-1:0] x_shifted = $signed(x_reg) >>> i;
    wire signed [EXT_WIDTH-1:0] y_shifted = $signed(y_reg) >>> i;
    
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            x_reg <= 0;
            y_reg <= 0;
            z_reg <= 0;
            i <= 0;
        end
        else begin
            case(state)
                IDLE: begin
                    if(start) begin
                        // Universal Pre-scaling: Load 32-bit products safely into 18-bit guarded registers
                        x_reg <= $signed({{2{x_prescaled[DATA_WIDTH-1]}}, x_prescaled[DATA_WIDTH-1:0]});
                        y_reg <= $signed({{2{y_prescaled[DATA_WIDTH-1]}}, y_prescaled[DATA_WIDTH-1:0]});
                        i <= 0;
                        z_reg <= $signed({{2{theta_in[DATA_WIDTH-1]}}, theta_in});
                    end
                end
                COMPUTE: begin
                    i <= i + 1;
                    if(z_reg >=0) begin //Rotate Anticlockwise
                        x_reg <= x_reg  - y_shifted;
                        y_reg <= y_reg + x_shifted;
                        z_reg <= z_reg - lut_angle;
                    end
                    else begin
                        x_reg <= x_reg + y_shifted;
                        y_reg <= y_reg - x_shifted;
                        z_reg <= z_reg + lut_angle;
                    end
                end
                DONE: i <= 0;
            endcase
        end
    end

    assign valid = (state == DONE);
    assign x_out = x_reg[DATA_WIDTH-1:0];
    assign y_out = y_reg[DATA_WIDTH-1:0];
endmodule