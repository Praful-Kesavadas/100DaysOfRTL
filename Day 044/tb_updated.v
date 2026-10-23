`timescale 1ns / 1ps

// =============================================================================
// Self-checking testbench for cordic_rotation  (Q2.14 data, Q3.13 angle)
//
//   1. Directed cases  - boundaries, the four quadrants, the +/-pi/2 flip point,
//                        the old ~99.88 deg convergence limit, +/-pi, extremes.
//   2. Sweep A         - sin/cos table: unit vector, -180..+180 deg in 1 deg steps.
//   3. Sweep B         - non-unit vectors in all quadrants, 5 deg steps.
//   4. Sweep C         - N_RANDOM seeded-random (x, y, theta) vectors, full circle.
//
//   Every vector is checked against a floating-point reference ($sin/$cos),
//   computed from the QUANTISED inputs the DUT actually saw, so the measured
//   error is the DUT's alone. Error is reported in LSBs of Q2.14 (1 LSB = 2^-14).
//   Latency (start edge -> valid) and the one-cycle valid pulse are checked too.
//
//   Every applied vector and DUT result is logged to rtl_results.txt, which
//   verify_cordic.py re-checks bit-exactly against a Python model of the RTL.
// =============================================================================
module tb_cordic_processor;

    parameter DATA_WIDTH = 16;
    parameter ITERATIONS = 16;

    localparam real Q14 = 16384.0;               // x, y  : Q2.14
    localparam real Q13 = 8192.0;                // theta : Q3.13
    localparam real PI  = 3.141592653589793;

    // Accuracy limit in Q2.14 LSBs. Worst case measured over >100k vectors is ~10-11 LSB
    // (floor-truncating >>> in 16 iterations + 14-bit angle LUT). A wrong LUT entry or a
    // broken quadrant gives hundreds-thousands of LSB, so 12 separates the two cleanly.
    // Keep in sync with TOL_LSB in verify_cordic.py.
    localparam real    TOL_LSB  = 12.0;
    localparam integer N_RANDOM = 5000;

    // Clock, reset, stimulus
    reg clk;
    reg nreset;
    reg start;
    reg signed [DATA_WIDTH-1:0] x_in;
    reg signed [DATA_WIDTH-1:0] y_in;
    reg signed [DATA_WIDTH-1:0] theta_in;

    wire signed [DATA_WIDTH-1:0] x_out;
    wire signed [DATA_WIDTH-1:0] y_out;
    wire valid;

    cordic_rotation_updated #(
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

    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Watchdog: a DUT that never raises valid must not hang the simulation
    initial begin
        #200_000_000;
        $display("[FAIL] WATCHDOG: simulation did not finish");
        $finish;
    end

    // ------------------------------------------------------------------------
    // Bookkeeping
    // ------------------------------------------------------------------------
    integer fd;
    integer seed;
    integer k, m;

    integer n_vec, n_fail;              // whole run
    integer sw_n, sw_fail;              // current sweep
    real    max_err_x, max_err_y;       // whole run, |error| in LSB
    real    sw_max_err;                 // current sweep
    real    sum_err;                    // whole run, sum of max(|ex|,|ey|)
    real    worst_err, worst_x, worst_y, worst_deg;
    integer lat_expected;

    // Round-to-nearest real -> fixed-point integer
    function integer to_fix;
        input real v;
        input real scale;
        begin
            to_fix = $rtoi(v * scale + ((v >= 0.0) ? 0.5 : -0.5));
        end
    endfunction

    // Uniform random real in [0, 1)
    function real urand01;
        input integer dummy;
        reg [31:0] r;
        begin
            r = $random(seed);
            r[31] = 1'b0;                         // non-negative: $itor treats the word as signed
            urand01 = $itor(r) / 2147483648.0;
        end
    endfunction

    // ------------------------------------------------------------------------
    // Apply one vector, wait for valid, check against the float reference.
    //   verbose = 1 : print the full case report (directed tests)
    //   verbose = 0 : stay silent unless the vector fails (sweeps)
    // ------------------------------------------------------------------------
    task run_vec(
        input [8*48-1:0] tc_name,
        input real       real_x,
        input real       real_y,
        input real       deg,
        input integer    verbose
    );
        real    xq, yq, thq, ex, ey, ox, oy, err_x, err_y, err;
        integer lat;
        reg     bad;
        begin
            @(posedge clk); #1;
            x_in     = to_fix(real_x, Q14);
            y_in     = to_fix(real_y, Q14);
            theta_in = to_fix(deg * PI / 180.0, Q13);
            start    = 1'b1;
            @(posedge clk); #1;               // DUT samples `start` on this edge
            start    = 1'b0;

            // Latency: count clock edges until valid rises
            lat = 0;
            while (!valid && lat < ITERATIONS + 8) begin
                @(posedge clk); #1;
                lat = lat + 1;
            end

            // Reference from the quantised inputs actually applied
            xq  = x_in / Q14;
            yq  = y_in / Q14;
            thq = theta_in / Q13;
            if (xq * xq + yq * yq >= 4.0)         // result would not fit Q2.14: a bad test, not a DUT bug
                $display("[FAIL] BAD STIMULUS in testbench: |v| = %0.3f >= 2.0 (%0s)", $sqrt(xq*xq + yq*yq), tc_name);
            ex  = xq * $cos(thq) - yq * $sin(thq);
            ey  = yq * $cos(thq) + xq * $sin(thq);

            ox    = $itor(x_out);
            oy    = $itor(y_out);
            err_x = ox - ex * Q14;
            err_y = oy - ey * Q14;
            if (err_x < 0.0) err_x = -err_x;
            if (err_y < 0.0) err_y = -err_y;
            err = (err_x > err_y) ? err_x : err_y;

            $fdisplay(fd, "%0d %0d %0d %0d %0d", x_in, y_in, theta_in, x_out, y_out);

            // valid must be a one-cycle pulse
            @(posedge clk); #1;
            bad = (err > TOL_LSB) || (lat != lat_expected) || valid || (xq * xq + yq * yq >= 4.0);

            n_vec  = n_vec + 1;
            sw_n   = sw_n + 1;
            if (err_x > max_err_x) max_err_x = err_x;
            if (err_y > max_err_y) max_err_y = err_y;
            if (err   > sw_max_err) sw_max_err = err;
            sum_err = sum_err + err;
            if (err > worst_err) begin
                worst_err = err; worst_x = xq; worst_y = yq; worst_deg = thq * 180.0 / PI;
            end
            if (bad) begin
                n_fail  = n_fail + 1;
                sw_fail = sw_fail + 1;
            end

            if (verbose || bad) begin
                $display("--------------------------------------------------------------------------------");
                $display("[%s] %0s", bad ? "FAIL" : "PASS", tc_name);
                $display("  Inputs   : X_in = %8.4f, Y_in = %8.4f, Angle = %8.2f deg (raw theta = %0d)",
                         xq, yq, thq * 180.0 / PI, theta_in);
                $display("  Raw Hex  : x_out = 16'h%04h, y_out = 16'h%04h", x_out, y_out);
                $display("  Hardware : X_out = %8.4f, Y_out = %8.4f", ox / Q14, oy / Q14);
                $display("  Expected : X_out = %8.4f, Y_out = %8.4f", ex, ey);
                $display("  Abs err  : x = %6.2f LSB, y = %6.2f LSB (limit %0.1f) | latency = %0d (expect %0d)",
                         err_x, err_y, TOL_LSB, lat, lat_expected);
            end
        end
    endtask

    // Reset the per-sweep counters
    task sweep_begin;
        begin
            sw_n = 0; sw_fail = 0; sw_max_err = 0.0;
        end
    endtask

    // Print one summary line for a finished sweep
    task sweep_end(input [8*48-1:0] name);
        begin
            $display("[%s] %0s : %0d vectors, max abs err = %0.2f LSB, out-of-tolerance = %0d",
                     (sw_fail == 0) ? "PASS" : "FAIL", name, sw_n, sw_max_err, sw_fail);
        end
    endtask

    // ------------------------------------------------------------------------
    // Main sequence
    // ------------------------------------------------------------------------
    real rx, ry, rdeg;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_cordic_processor);

        fd = $fopen("rtl_results.txt", "w");
        seed = 20261022;               // fixed seed: runs are reproducible
        n_vec = 0; n_fail = 0; sw_n = 0; sw_fail = 0;
        max_err_x = 0.0; max_err_y = 0.0; sw_max_err = 0.0; sum_err = 0.0;
        worst_err = 0.0; worst_x = 0.0; worst_y = 0.0; worst_deg = 0.0;
        lat_expected = ITERATIONS;

        nreset   = 1'b0;
        start    = 1'b0;
        x_in     = 0;
        y_in     = 0;
        theta_in = 0;
        #20;
        nreset   = 1'b1;
        #20;

        $display("================================================================================");
        $display("CORDIC ROTATION: SELF-CHECKING VERIFICATION (Q2.14 data, Q3.13 angle)");
        $display("Tolerance %0.1f LSB (1 LSB = 2^-14), expected latency %0d cycles", TOL_LSB, lat_expected);
        $display("================================================================================");

        // ---------------- 1. Directed cases ----------------
        sweep_begin;

        // Original cases
        run_vec("BOUNDARY 1: Zero Vector Input",                 0.0,  0.0,  45.0, 1);
        run_vec("BOUNDARY 2: Zero Angle Rotation",               1.0,  0.0,   0.0, 1);
        run_vec("CASE 3: Pure Sin/Cos Gen (+45 deg)",            1.0,  0.0,  45.0, 1);
        run_vec("CASE 4: Pure Sin/Cos Gen (+30 deg)",            1.0,  0.0,  30.0, 1);
        run_vec("CASE 5: Pure Sin/Cos Gen (-45 deg)",            1.0,  0.0, -45.0, 1);
        run_vec("CASE 6: Arbitrary 2D Vector Rotation",          1.0,  0.5,  30.0, 1);
        run_vec("CASE 7: Negative Coordinate Vector Rotation",  -0.5,  0.5, -30.0, 1);
        run_vec("BOUNDARY 8: +89 deg",                           1.0,  0.0,  89.0, 1);

        // Tiny angle
        run_vec("SMALL: +0.01 deg",                              1.0,  0.0,   0.01, 1);

        // pi/2 boundary: exactly pi/2 takes the no-flip path, one LSB above takes the flip path
        run_vec("QUADRANT: +90 deg (pi/2, no flip)",             1.0,  0.0,  90.0, 1);
        run_vec("QUADRANT: -90 deg (-pi/2, no flip)",            1.0,  0.0, -90.0, 1);
        run_vec("QUADRANT: +90.01 deg (just past pi/2, flip)",   1.0,  0.0,  90.01, 1);
        run_vec("QUADRANT: -90.01 deg (just past -pi/2, flip)",  1.0,  0.0, -90.01, 1);

        // The old convergence limit (~99.88 deg) and beyond: plain CORDIC fails here
        run_vec("QUADRANT: +99.9 deg (old convergence limit)",   1.0,  0.0,  99.9, 1);
        run_vec("QUADRANT: +120 deg",                            1.0,  0.0, 120.0, 1);
        run_vec("QUADRANT: +135 deg, 2D vector",                 0.8, -0.6, 135.0, 1);
        run_vec("QUADRANT: -120 deg",                            1.0,  0.0, -120.0, 1);
        run_vec("QUADRANT: -135 deg, 2D vector",                -0.8,  0.6, -135.0, 1);
        run_vec("QUADRANT: +179.99 deg",                         1.0,  0.0, 179.99, 1);
        run_vec("QUADRANT: +180 deg (pi)",                       1.0,  0.0, 180.0, 1);
        run_vec("QUADRANT: -180 deg (-pi)",                      1.0,  0.0, -180.0, 1);

        // Theta port limits (+/-4 rad, beyond +/-pi but still representable)
        run_vec("EXTREME: +229 deg (near +4 rad, port limit)",   1.0,  0.0,  229.0, 1);
        run_vec("EXTREME: -229 deg (near -4 rad, port limit)",   1.0,  0.0, -229.0, 1);

        // Near full-scale vector: |v| = 1.98, output must still fit Q2.14
        run_vec("FULL SCALE: |v| = 1.98 at +45 deg",             1.4,  1.4,  45.0, 1);
        run_vec("FULL SCALE: |v| = 1.98 at -135 deg",           -1.4,  1.4, -135.0, 1);

        sweep_end("DIRECTED CASES");

        // Keep the waveform file small: record the directed section only
        $dumpoff;

        // ---------------- 2. Sweep A: sin/cos table ----------------
        sweep_begin;
        for (k = -180; k <= 180; k = k + 1)
            run_vec("sweep A", 1.0, 0.0, $itor(k), 0);
        sweep_end("SWEEP A: unit vector, -180..+180 deg, 1 deg step");

        // ---------------- 3. Sweep B: non-unit vectors ----------------
        sweep_begin;
        for (k = -180; k <= 180; k = k + 5) begin
            run_vec("sweep B", 0.5,  0.5, $itor(k), 0);
            run_vec("sweep B", -1.2, 0.7, $itor(k), 0);
            run_vec("sweep B", 1.4, -1.0, $itor(k), 0);
            run_vec("sweep B", -0.3, -1.5, $itor(k), 0);
        end
        sweep_end("SWEEP B: 4 non-unit vectors, 5 deg step");

        // ---------------- 4. Sweep C: seeded random ----------------
        sweep_begin;
        for (m = 0; m < N_RANDOM; m = m + 1) begin
            rx   = (2.0 * urand01(0) - 1.0) * 1.4;     // |x|,|y| <= 1.4 -> |v| <= 1.98 < 2
            ry   = (2.0 * urand01(0) - 1.0) * 1.4;
            rdeg = (2.0 * urand01(0) - 1.0) * 180.0;
            run_vec("sweep C", rx, ry, rdeg, 0);
        end
        sweep_end("SWEEP C: random x, y, theta (seeded)");

        // ---------------- Summary ----------------
        $fclose(fd);
        $display("================================================================================");
        $display("SUMMARY");
        $display("  vectors run        : %0d", n_vec);
        $display("  max abs err  x / y : %0.2f / %0.2f LSB   (limit %0.1f LSB)", max_err_x, max_err_y, TOL_LSB);
        $display("  mean abs err       : %0.2f LSB", sum_err / n_vec);
        $display("  worst case at      : x = %0.4f, y = %0.4f, angle = %0.2f deg", worst_x, worst_y, worst_deg);
        $display("  latency            : %0d cycles, valid pulse 1 cycle", lat_expected);
        if (n_fail == 0)
            $display("[PASS] ALL TESTS PASSED (%0d vectors)", n_vec);
        else
            $display("[FAIL] %0d of %0d vectors out of tolerance", n_fail, n_vec);
        $display("================================================================================");
        $finish;
    end

endmodule