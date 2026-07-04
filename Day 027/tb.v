`timescale 1ns / 1ps

module tb_bcd_counter_2digit;

    // Overriding the parameter to test a Divide-by-4 architecture
    parameter DIV_FACTOR = 4;

    reg clk_in;
    reg nreset;
    reg start;
    wire clk_out;

    clk_divider_even #(
        .DIVIDE_BY(DIV_FACTOR)
    ) uut (
        .clk_in(clk_in),
        .nreset(nreset),
        .start(start),
        .clk_out(clk_out)
    );

    initial begin
        clk_in = 1'b0;
        forever #5 clk_in = ~clk_in;
    end

    initial begin
        // Configure VCD pipeline trace capture targeting this explicit scope
        $dumpfile("clk_divider_even.vcd");
        $dumpvars(0);

        // --- Test Case 1: Asynchronous Power-on Initialization ---
        // Escapes the simulation X-state trap cleanly
        nreset = 1'b0; start = 1'b0; #12;
        nreset = 1'b1; #10;
        
        // --- Test Case 2: Activate Frequency Division ---
        // For DIVIDE_BY = 4: MID_POINT = 1. Internal counter cycles 0 -> 1 -> 0 -> 1
        start = 1'b1;
        #160; // Let it run through 4 complete output clock periods (40ns each)
        
        // --- Test Case 3: Synchronous Operation Freeze ---
        // Drop the start pin mid-cycle. clk_out must hold its state stably with no jitter.
        start = 1'b0; 
        #30; 
        
        // --- Test Case 4: Resume to Final Termination Clear ---
        start = 1'b1; #40;
        nreset = 1'b0; #10;

        $finish;
    end

endmodule