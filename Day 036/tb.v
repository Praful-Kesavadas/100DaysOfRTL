`timescale 1ns / 1ps

module tb_stopwatch;

    reg clk;
    reg nreset;
    reg start;
    reg pause;
    reg split_lap;
    reg clear;

    wire [7:0] minutes;
    wire [7:0] seconds;
    wire [7:0] centisec;

    // Instantiate stopwatch with low frequency for faster simulation runs
    stopwatch #(.FREQ_MHz(1)) uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .pause(pause),
        .split_lap(split_lap),
        .clear(clear),
        .minutes(minutes),
        .seconds(seconds),
        .centisec(centisec)
    );

    // 100 MHz reference clock tree
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_stopwatch);

        // Global Reset Initialization
        nreset = 1'b0; start = 1'b0; pause = 1'b0; split_lap = 1'b0; clear = 1'b0;
        #20; nreset = 1'b1; #20;

        // --- Run Scenario 1: Start Stopwatch and let it increment ---
        $display("[SIM] Launching counting cycle...");
        start <= 1'b1; @(posedge clk); start <= 1'b0;
        
        // Wait long enough for centiseconds and single seconds to increment
        repeat (150000) @(posedge clk);

        // --- Run Scenario 2: Invoke Split/Lap Feature ---
        $display("[SIM] Activating Split-Lap. Display outputs should freeze while internals run.");
        split_lap <= 1'b1; @(posedge clk); split_lap <= 1'b0;
        repeat (50000) @(posedge clk); // Internal counters run wild here

        // --- Run Scenario 3: Release Split/Lap Feature ---
        $display("[SIM] Releasing Split-Lap. Display output should instantly snap to internal values.");
        split_lap <= 1'b1; @(posedge clk); split_lap <= 1'b0;
        repeat (50000) @(posedge clk);

        // --- Run Scenario 4: Pause Operations ---
        $display("[SIM] Pausing stopwatch execution...");
        pause <= 1'b1; @(posedge clk); pause <= 1'b0;
        repeat (20000) @(posedge clk); // Timeline stands completely frozen

        // --- Run Scenario 5: Re-Start and let it run to a minute rollover ---
        $display("[SIM] Resuming stopwatch to verify high-order rollovers...");
        start <= 1'b1; @(posedge clk); start <= 1'b0;
        repeat (500000) @(posedge clk); // Massive run loop to check multi-tier carry propagation

        // --- Run Scenario 6: Clear Core Register Banks ---
        $display("[SIM] Executing absolute system clear command.");
        clear <= 1'b1; @(posedge clk); clear <= 1'b0;
        repeat (2000) @(posedge clk);

        $finish;
    end

endmodule