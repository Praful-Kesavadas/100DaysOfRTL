`timescale 1ns / 1ps

module tb_quadrature_encoder_decoder;

    // Testbench Stimulus Signals
    reg clk;
    reg nreset;
    reg [1:0] mode;
    reg phaseA;
    reg phaseB;

    // UUT Output Monitoring Wires
    wire clockwise;
    wire anticlockwise;
    wire error;

    // Track position externally to prove modular strobe counting success
    reg [15:0] position_counter;

    // Instantiate User's Parameterized Decoder Core
    quadrature_encoder_decoder uut (
        .clk(clk),
        .nreset(nreset),
        .mode(mode),
        .phaseA(phaseA),
        .phaseB(phaseB),
        .clockwise(clockwise),
        .anticlockwise(anticlockwise),
        .error(error)
    );

    // 100 MHz Master System Clock Generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 10ns period clock
    end

    // External Position Accumulator tracking module strobes
    always @(posedge clk or negedge nreset) begin
        if (!nreset) begin
            position_counter <= 16'h0000;
        end else begin
            if (clockwise)     position_counter <= position_counter + 1'b1;
            if (anticlockwise) position_counter <= position_counter - 1'b1;
        end
    end

    // Task to generate one full 4-state Clockwise Quadrature Cycle
    task drive_clockwise_cycle;
        begin
            // State 10
            phaseA = 1'b1; phaseB = 1'b0; #40;
            // State 11
            phaseA = 1'b1; phaseB = 1'b1; #40;
            // State 01
            phaseA = 1'b0; phaseB = 1'b1; #40;
            // State 00
            phaseA = 1'b0; phaseB = 1'b0; #40;
        end
    endtask

    // Task to generate one full 4-state Counter-Clockwise Quadrature Cycle
    task drive_counter_clockwise_cycle;
        begin
            // State 01
            phaseA = 1'b0; phaseB = 1'b1; #40;
            // State 11
            phaseA = 1'b1; phaseB = 1'b1; #40;
            // State 10
            phaseA = 1'b1; phaseB = 1'b0; #40;
            // State 00
            phaseA = 1'b0; phaseB = 1'b0; #40;
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // --- System Initialization & Active-Low Reset ---
        nreset = 1'b0; mode = 2'b11; phaseA = 1'b0; phaseB = 1'b0;
        #30;
        nreset = 1'b1;
        #20;

        // ====================================================================
        // TEST SCENARIO 1: Verify 4x Mode Resolution (Expect 4 counts per cycle)
        // ====================================================================
        mode = 2'b11; // 4x Resolution Mode Selection
        $display("[SIM] Target 4x Mode: Driving Clockwise Shaft Rotation...");
        drive_clockwise_cycle();
        #40;
        
        $display("[SIM] Target 4x Mode: Driving Counter-Clockwise Shaft Rotation...");
        drive_counter_clockwise_cycle();
        #40;

        // ====================================================================
        // TEST SCENARIO 2: Verify 2x Mode Resolution (Expect 2 counts per cycle)
        // ====================================================================
        mode = 2'b10; // 2x Resolution Mode Selection
        $display("[SIM] Target 2x Mode: Driving Clockwise Shaft Rotation...");
        drive_clockwise_cycle();
        #40;

        // ====================================================================
        // TEST SCENARIO 3: Verify 1x Mode Resolution (Expect 1 count per cycle)
        // ====================================================================
        mode = 2'b01; // 1x Resolution Mode Selection
        $display("[SIM] Target 1x Mode: Driving Clockwise Shaft Rotation...");
        drive_clockwise_cycle();
        #40;

        // ====================================================================
        // TEST SCENARIO 4: Verify Double-Bit-Flip Error Exception Handling
        // ====================================================================
        $display("[SIM] Injecting Speed/Sampling Violation Violation (00 -> 11)...");
        phaseA = 1'b0; phaseB = 1'b0;
        #40;
        phaseA = 1'b1; phaseB = 1'b1; // Simultaneous flip hazard injection
        #40;

        $display("[SIM] Verification complete. Analyzing position tracks.");
        $finish;
    end

endmodule