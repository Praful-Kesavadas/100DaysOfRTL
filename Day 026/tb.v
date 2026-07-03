`timescale 1ns / 1ps

module tb_bcd_counter;

    reg clk;
    reg nreset;
    reg start;
    wire [3:0] count;
    wire carry_out;

    bcd_counter uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .count(count),
        .carry_out(carry_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // --- Test 1: Asynchronous Clean Startup ---
        nreset = 1'b0; start = 1'b0; #12;
        nreset = 1'b1; #10;
        
        // --- Test 2: Enable Decimal Accumulation Sequence ---
        start = 1'b1; 
        #250; // Let it count through 2.5 full decades (0->9->0->9)
        
        // --- Test 3: Synchronous Intermittent Freeze ---
        start = 1'b0; #30; // Freeze state stably mid-stream
        
        // --- Test 4: Resume to Final Termination Clear ---
        start = 1'b1; #40;
        nreset = 1'b0; #10;

        $finish;
    end

endmodule