`timescale 1ns / 1ps

module tb_edge_detector_sequential;

    reg clk;
    reg nreset;
    reg signal;
    wire rising_edge;
    wire falling_edge;
    wire same_level;

    edge_detector_seqential uut (
        .clk(clk),
        .nreset(nreset),
        .signal(signal),
        .rising_edge(rising_edge),
        .falling_edge(falling_edge),
        .same_level(same_level)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // --- Step 1: Clear System State ---
        nreset = 1'b0; signal = 1'b0; #12;
        nreset = 1'b1; #10;

        // --- Step 2: Inject Asynchronous Rising Edge ---
        // Slam input high at 23ns (right in the middle of a clock phase)
        #1;
        signal = 1'b1; 
        #100; // Hold high to watch rising pulse clear back to 0

        // --- Step 3: Inject Asynchronous Falling Edge ---
        // Slam input low at 127ns
        #4;
        signal = 1'b0;
        #100;

        $finish;
    end

endmodule