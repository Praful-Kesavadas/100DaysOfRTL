`timescale 1ns / 1ps

module tb_moduloN_counter;

    parameter TEST_WIDTH = 4;
    parameter TEST_MAX = 10;

    reg clk;
    reg nreset;
    reg start;
    wire [TEST_WIDTH-1:0] count;
    wire max_count;

    moduloN_counter #(
        .WIDTH(TEST_WIDTH),
        .MAX_COUNT(TEST_MAX)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .count(count),
        .max_count(max_count)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // --- Test 1: Asynchronous Clear ---
        nreset = 1'b0; start = 1'b0; #12;
        nreset = 1'b1; #10;
        
        // --- Test 2: Enable Counting Stream ---
        start = 1'b1; 
        #120; // Let it run through a full cycle (0->9->0) and verify wrap-around
        
        // --- Test 3: Data-path Freeze ---
        start = 1'b0; #20; // Freeze state mid-stream
        
        // --- Test 4: Resume to Final Reset ---
        start = 1'b1; #40;
        nreset = 1'b0; #10;

        $finish;
    end

endmodule