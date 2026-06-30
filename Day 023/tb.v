`timescale 1ns / 1ps

module tb_syn_counter;

    reg clk;
    reg count_up;
    reg nreset;
    wire [3:0] q;

    syn_counter uut (
        .clk(clk),
        .count_up(count_up),
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

        // --- Test Case 1: Power-on Asynchronous Initialization ---
        nreset = 1'b0; count_up = 1'b1; #12;
        
        // --- Test Case 2: Release Reset to Parallel Up-Counting ---
        nreset = 1'b1; 
        #60; // Let it increment up: 0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6
        
        // --- Test Case 3: Mid-Cycle Synchronous Direction Flip ---
        // Change direction pin to 0. Watch the lookahead steer data down instantly!
        count_up = 1'b0; 
        #50; // Let it decrement down over 5 clock cycles
        
        // --- Test Case 4: Reverse Direction Back to Up-Count ---
        count_up = 1'b1; #30;
        
        // --- Test Case 5: Final Asynchronous Strike ---
        #2;
        nreset = 1'b0; #10;

        $finish;
    end

endmodule