`timescale 1ns / 1ps

module tb_switch_debouncer;

    reg clk;
    reg nreset;
    reg signal_in;
    wire signal_out;

    // Instantiate debouncer with a small window (10 microsecond scale) for fast simulation
    switch_debouncer #(
        .CLK_FREQUENCY(100_000_000), 
        .DEBOUNCE_MS(1) // 1ms target window
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .signal_in(signal_in),
        .signal_out(signal_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        nreset = 1'b0; signal_in = 1'b0; #22;
        nreset = 1'b1; #20;

        // --- Simulate Mechanical Button Bouncing Chatter ---
        $display("[TIMELINE] Initiating messy button press with contact chatter...");
        signal_in = 1'b1; #5000;  // Initial contact bounce
        signal_in = 1'b0; #8000;  // Drop down bounce
        signal_in = 1'b1; #4000;  // Up bounce
        signal_in = 1'b0; #12000; // Deep low bounce (resets timer progress)
        
        // --- Settle Stable High State ---
        signal_in = 1'b1; 
        $display("[TIMELINE] Signal settled at 1. Verifying stabilization countdown window...");
        
        // Wait 1.2ms (long enough to clear our 1ms debounce parameter setting)
        #1200000; 

        // --- Simulate Releasing Button Chatter ---
        signal_in = 1'b0; #6000;
        signal_in = 1'b1; #4000;
        signal_in = 1'b0; 
        
        #1200000; // Allow it to filter and stabilize back to low
        
        $display("[TIMELINE] Verification run complete.");
        $finish;
    end

endmodule