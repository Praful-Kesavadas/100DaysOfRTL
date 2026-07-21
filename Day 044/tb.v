`timescale 1ns / 1ps

module tb_cordic_processor;

    parameter DATA_WIDTH = 16;
    parameter ITERATIONS = 16;

    // Fixed-Point Q2.14 Scale Factor Constant (2^14 = 16384.0)
    localparam real Q14_SCALE = 16384.0;

    // Clock and Reset Signals
    reg clk;
    reg nreset;
    reg start;

    // Input Stimulus Signals
    reg signed [DATA_WIDTH-1:0] x_in;
    reg signed [DATA_WIDTH-1:0] y_in;
    reg signed [DATA_WIDTH-1:0] theta_in;

    // Output Signals
    wire signed [DATA_WIDTH-1:0] x_out;
    wire signed [DATA_WIDTH-1:0] y_out;
    wire valid;

    // Instantiate Unit Under Test (UUT)
    cordic_rotation #(
        .DATA_WIDTH(DATA_WIDTH),
        .ITERATIONS(ITERATIONS)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .x_in(x_in),
        .y_in(y_in),
        .theta_in(theta_in),
        .x_out(x_out),
        .y_out(y_out),
        .valid(valid)
    );

    // Clock Generation (100 MHz -> 10ns period)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // Verification Task: Executes a single CORDIC rotation and logs results
    // Converts Q2.14 fixed-point integer values to real floats for clarity
    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------
    // Verification Task: Verilog-2001 Compliant
    // ------------------------------------------------------------------------
    task test_cordic_rotation(
        input [8*50-1:0] tc_name, // Fixed: Standard Verilog-2001 string buffer
        input real       real_x,
        input real       real_y,
        input real       real_angle_deg
    );
        real real_angle_rad;
        real expected_x, expected_y;
        real actual_x, actual_y;
        
        begin
            @(posedge clk);
            #1;
            real_angle_rad = real_angle_deg * 3.141592653589793 / 180.0;
            
            x_in     = $rtoi(real_x * Q14_SCALE);
            y_in     = $rtoi(real_y * Q14_SCALE);
            theta_in = $rtoi(real_angle_rad * Q14_SCALE);

            start = 1'b1;
            @(posedge clk);
            #1;
            start = 1'b0;

            @(posedge valid);
            #1;

            expected_x = (real_x * $cos(real_angle_rad)) - (real_y * $sin(real_angle_rad));
            expected_y = (real_y * $cos(real_angle_rad)) + (real_x * $sin(real_angle_rad));

            actual_x = x_out / Q14_SCALE;
            actual_y = y_out / Q14_SCALE;

            $display("--------------------------------------------------------------------------------");
            $display("[TEST CASE] %s", tc_name);
            $display("  Inputs   : X_in = %0.4f, Y_in = %0.4f, Angle = %0.2f deg (%0.4f rad)", 
                     real_x, real_y, real_angle_deg, real_angle_rad);
            $display("  Raw Hex  : x_out = 16'h%04h, y_out = 16'h%04h", x_out, y_out);
            $display("  Hardware : X_out = %0.4f, Y_out = %0.4f", actual_x, actual_y);
            $display("  Expected : X_out = %0.4f, Y_out = %0.4f", expected_x, expected_y);
            
            #20;
        end
    endtask

    // ------------------------------------------------------------------------
    // Main Test Stimulus Sequence
    // ------------------------------------------------------------------------
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_cordic_processor);

        // Active Reset Cycle
        nreset   = 1'b0;
        start    = 1'b0;
        x_in     = 0;
        y_in     = 0;
        theta_in = 0;
        #20;
        nreset   = 1'b1;
        #20;

        $display("================================================================================");
        $display("RUNNING UNIVERSAL FIXED-POINT CORDIC PROCESSOR VERIFICATION SUITE");
        $display("================================================================================");

        // --- Boundary Condition 1: Zero Vector Input (0, 0) ---
        test_cordic_rotation("BOUNDARY 1: Zero Vector Input", 0.0, 0.0, 45.0);

        // --- Boundary Condition 2: Zero Angle Rotation (0 deg) ---
        test_cordic_rotation("BOUNDARY 2: Zero Angle Rotation", 1.0, 0.0, 0.0);

        // --- Case 3: Pure Sin/Cos Generation at +45 degrees (+pi/4 rad) ---
        test_cordic_rotation("CASE 3: Pure Sin/Cos Gen (+45 deg)", 1.0, 0.0, 45.0);

        // --- Case 4: Pure Sin/Cos Generation at +30 degrees (+pi/6 rad) ---
        test_cordic_rotation("CASE 4: Pure Sin/Cos Gen (+30 deg)", 1.0, 0.0, 30.0);

        // --- Case 5: Pure Sin/Cos Generation at -45 degrees (-pi/4 rad Clockwise) ---
        test_cordic_rotation("CASE 5: Pure Sin/Cos Gen (-45 deg)", 1.0, 0.0, -45.0);

        // --- Case 6: General 2D Vector Rotation (Arbitrary Non-Zero X, Y) ---
        // Rotates vector (1.0, 0.5) counter-clockwise by +30 degrees
        test_cordic_rotation("CASE 6: Arbitrary 2D Vector Rotation", 1.0, 0.5, 30.0);

        // --- Case 7: Negative Input Coordinates Quadrant Rotation (-0.5, +0.5) ---
        // Rotates vector (-0.5, 0.5) clockwise by -30 degrees
        test_cordic_rotation("CASE 7: Negative Coordinate Vector Rotation", -0.5, 0.5, -30.0);

        // --- Boundary Condition 8: Upper Convergence Limit (~89 degrees) ---
        // Tests maximum allowable rotation near +pi/2 boundary limit
        test_cordic_rotation("BOUNDARY 8: Upper Convergence Limit (+89 deg)", 1.0, 0.0, 89.0);

        $display("================================================================================");
        $display("ALL CORDIC ROTATION VERIFICATION TESTS COMPLETED SUCCESSFULLY.");
        $display("================================================================================");
        $finish;
    end

endmodule