`timescale 1ns / 1ps

module tb_keypad_controller;

    // Testbench Stimulus Signals
    reg clk;
    reg nreset;
    wire [3:0] col_in;
    
    // UUT Monitoring Outputs
    wire [3:0] row_out;
    wire [3:0] key_code;
    wire key_valid;

    // Keypad Emulation Control Registers
    reg        sim_key_down;
    reg [1:0]  sim_pressed_row; // 0-3 index of the row button pressed
    reg [1:0]  sim_pressed_col; // 0-3 index of the col button pressed

    // Instantiate UUT with scaled down parameters for lightning-fast simulation
    keypad_controller #(
        .FREQ_MHz(1),     // 1 MHz clock for testing (1 cycle = 1us)
        .DEBOUNCE_MS(1)   // 1 ms debounce threshold (requires 1000 clock ticks)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .col_in(col_in),
        .row_out(row_out),
        .key_code(key_code),
        .key_valid(key_valid)
    );

    // 100 MHz Testbench Master Clock Source (but UUT treats as 1MHz parameter width)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 10ns clock period
    end

    // Open-Drain Keypad Switch Emulation Matrix
    // When a key switch is pressed, it shorts that row line directly to that column line.
    // If no key is down, internal pull-up network pins float default high (1'b1).
    assign col_in[0] = (sim_key_down && sim_pressed_col == 2'd0) ? row_out[sim_pressed_row] : 1'b1;
    assign col_in[1] = (sim_key_down && sim_pressed_col == 2'd1) ? row_out[sim_pressed_row] : 1'b1;
    assign col_in[2] = (sim_key_down && sim_pressed_col == 2'd2) ? row_out[sim_pressed_row] : 1'b1;
    assign col_in[3] = (sim_key_down && sim_pressed_col == 2'd3) ? row_out[sim_pressed_row] : 1'b1;

    // Automated Task to emulate physical key activation profiles
    task simulate_keystroke(input [1:0] row_idx, input [1:0] col_idx, input integer press_duration_us);
        begin
            $display("[SIM] Activating Switch Location: Row %0d, Col %0d", row_idx, col_idx);
            sim_pressed_row = row_idx;
            sim_pressed_col = col_idx;
            sim_key_down    = 1'b1;
            
            // Hold button contact down for the physical interaction window
            #(press_duration_us * 1000);
            
            $display("[SIM] Releasing Switch Location: Row %0d, Col %0d", row_idx, col_idx);
            sim_key_down    = 1'b0;
            
            // Wait for release state stabilization clearing rules to settle
            #200000; 
        end
    endtask

    initial begin
        // Setup waveform visualization logs
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // --- System Hard Reset Initialization ---
        nreset       = 1'b0;
        sim_key_down = 1'b0;
        sim_pressed_row = 2'd0;
        sim_pressed_col = 2'd0;
        #100;
        nreset       = 1'b1;
        #500; // Let CDC synchronization buffers clear

        // ====================================================================
        // TEST SCENARIO 1: Simulate pressing Key '5' (Row 1, Col 1 -> Target Code 4'h5)
        // ====================================================================
        // Valid Press 
        simulate_keystroke(2'd1, 2'd1, 2500);

        // ====================================================================
        // TEST SCENARIO 2: Simulate pressing Key 'A' (Row 0, Col 3 -> Target Code 4'hA)
        // ====================================================================
        simulate_keystroke(2'd0, 2'd3, 2500);

        // ====================================================================
        // TEST SCENARIO 3: Filter Noise Glitch (Should NOT trigger valid output)
        // ====================================================================
        $display("[SIM] Injecting rapid noise spike on grid line (Under Debounce Threshold)...");
        sim_pressed_row = 2'd2;
        sim_pressed_col = 2'd0;
        sim_key_down    = 1'b1;
        #5000; // 5 microseconds - well below our 10us filter target
        sim_key_down    = 1'b0;
        #200000;

        // ====================================================================
        // TEST SCENARIO 4: Simulate pressing Key '#' (Row 3, Col 2 -> Target Code 4'hF)
        // ====================================================================
        simulate_keystroke(3'd3, 2'd2, 2500);

        $display("[SIM] Multi-Keystroke Matrix Sweep Complete.");
        $finish;
    end

endmodule