`timescale 1ns / 1ps

module tb_circular_counter;

    reg clk;
    reg nreset;
    reg counter_mode;
    wire [3:0] q;

    circular_counter uut (
        .clk(clk),
        .nreset(nreset),
        .counter_mode(counter_mode),
        .q(q)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // --- Test Case 1: Boot Up in Ring Counter Mode (counter_mode = 0) ---
        nreset = 1'b0; counter_mode = 1'b0; #12;
        nreset = 1'b1; 
        #50; // Cycles through 4 states: 0001 -> 0010 -> 0100 -> 1000

        // --- Test Case 2: Dynamic Mode Shift to Johnson (counter_mode = 1) ---
        // Flip mode selection and strike reset to initialize the new vector
        counter_mode = 1'b1;
        nreset = 1'b0; #10;
        nreset = 1'b1;
        #100; // Cycles through 8 states: 0000 -> 0001 -> 0011 -> 0111 -> 1111...

        // --- Test Case 3: Final Safe Clear ---
        nreset = 1'b0; #10;
        
        $finish;
    end

endmodule