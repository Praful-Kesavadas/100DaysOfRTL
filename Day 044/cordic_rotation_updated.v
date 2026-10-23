// =============================================================================
// CORDIC rotation mode : (x_out, y_out) = rotate( (x_in, y_in), theta_in )
//
//   Sin/cos generation  : x_in = 1.0, y_in = 0  ->  x_out = cos(theta), y_out = sin(theta)
//
//   x, y    : signed Q2.14. Keep |(x,y)| < 2.0 so the rotated result is representable.
//   theta   : signed Q3.13 radians  (CHANGED: was Q2.14, which cannot hold +/-pi).
//             Representable range is +/-4.0 rad; the full circle [-pi, +pi] is supported.
//   Latency : ITERATIONS clock cycles from the edge that samples `start` to `valid`.
//             `valid` is a one-cycle pulse; x_out / y_out are stable while it is high.
//   ITERATIONS must be <= 16 (the arctan LUT has 16 entries).
//
//   NEW - quadrant pre-rotation:
//   Plain CORDIC only converges for |z| <= sum(arctan(2^-i)) = ~99.88 deg, so the
//   old design silently broke beyond that. For |theta| > pi/2 the input vector is
//   rotated by pi (negate x and y) and pi is added to / subtracted from theta. The
//   residual angle is then within +/-pi/2, inside the convergence range.
// =============================================================================
module cordic_rotation_updated#(parameter DATA_WIDTH = 16, parameter ITERATIONS = 16
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

    //pi and pi/2 in Q4.14 (the format z_reg works in)
    localparam signed [EXT_WIDTH-1:0] PI_Q14      = 18'sd51472;  // round(pi   * 2^14)
    localparam signed [EXT_WIDTH-1:0] HALF_PI_Q14 = 18'sd25736;  // round(pi/2 * 2^14)

    //To prevent the truncation
    wire signed [31:0] x_in_32 = {{16{x_in[DATA_WIDTH-1]}}, x_in};
    wire signed [31:0] y_in_32 = {{16{y_in[DATA_WIDTH-1]}}, y_in};
    wire signed [31:0] k_32    = {{16{CORDIC_1_K[DATA_WIDTH-1]}}, CORDIC_1_K};

    //Prescaling of the inputs
    wire signed [2*DATA_WIDTH-1:0] x_prescaled = (x_in_32 * CORDIC_1_K) >>> 14;
    wire signed [2*DATA_WIDTH-1:0] y_prescaled = (y_in_32 * CORDIC_1_K) >>> 14;

    //Quadrant pre-rotation
    //Q3.13 theta_in -> Q4.14: one left shift, sign bit replicated
    wire signed [EXT_WIDTH-1:0] theta_ext = $signed({theta_in[DATA_WIDTH-1], theta_in, 1'b0});
    wire theta_hi = (theta_ext >  HALF_PI_Q14);   // theta >  +pi/2
    wire theta_lo = (theta_ext < -HALF_PI_Q14);   // theta <  -pi/2
    wire flip     = theta_hi | theta_lo;          // rotate the vector by pi
    wire signed [EXT_WIDTH-1:0] theta_red = theta_hi ? (theta_ext - PI_Q14) :
                                            theta_lo ? (theta_ext + PI_Q14) : theta_ext;

    //Prescaled inputs widened to the guarded register width, negated when flipping
    wire signed [EXT_WIDTH-1:0] x_pre = $signed({{2{x_prescaled[DATA_WIDTH-1]}}, x_prescaled[DATA_WIDTH-1:0]});
    wire signed [EXT_WIDTH-1:0] y_pre = $signed({{2{y_prescaled[DATA_WIDTH-1]}}, y_prescaled[DATA_WIDTH-1:0]});
    wire signed [EXT_WIDTH-1:0] x_load = flip ? -x_pre : x_pre;
    wire signed [EXT_WIDTH-1:0] y_load = flip ? -y_pre : y_pre;

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
                        // Pre-scaled (and, for |theta| > pi/2, pi-rotated) vector plus the reduced angle
                        x_reg <= x_load;
                        y_reg <= y_load;
                        z_reg <= theta_red;
                        i <= 0;
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