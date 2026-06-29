`timescale 1ns / 1ps

module tb_ripple_counter_async;

    reg clk;
    reg start;
    reg nreset;
    wire [3:0] q;

    ripple_counter_async uut (
        .clk(clk),
        .start(start),
        .nreset(nreset),
        .q(q)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // --- Test Case 1: Power-on Asynchronous Clear ---
        nreset = 1'b0; start = 1'b0; #12;
        
        // --- Test Case 2: Release Reset with Start Disabled ---
        nreset = 1'b1; #20; // Counter must hold flat at 4'h0
        
        // --- Test Case 3: Enable Counter Progress (start = 1) ---
        start = 1'b1; #160; // Let it count up through multiple states
        
        // --- Test Case 4: Synchronous Data-gating Hold ---
        start = 1'b0; #30;  // Holds current value stably without clock glitching
        
        // --- Test Case 5: Resume and Clear ---
        start = 1'b1; #40;
        nreset = 1'b0; #10;

        $finish;
    end

endmodule