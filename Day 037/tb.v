`timescale 1ns / 1ps

module tb_lfsr_galois;

    reg clk;
    reg nreset;
    reg enable;

    wire [3:0] q_4bit;
    wire [7:0] q_8bit;

    // Instance 1: Default 4-Bit Configuration (f(x) = x^4 + x^3 + 1)
    lfsr_galois #(.WIDTH(4), .TAPS(4'b1000)) uut_4bit (
        .clk(clk),
        .nreset(nreset),
        .enable(enable),
        .q(q_4bit)
    );

    // Instance 2: Scaled 8-Bit Configuration (f(x) = x^8 + x^6 + x^5 + x^4 + 1)
    lfsr_galois #(.WIDTH(8), .TAPS(8'b01110000)) uut_8bit (
        .clk(clk),
        .nreset(nreset),
        .enable(enable),
        .q(q_8bit)
    );

    // 100 MHz clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // Active Master Clear
        nreset = 1'b0; enable = 1'b0;
        #20;
        nreset = 1'b1; 
        @(posedge clk);
        
        // --- Scenario 1: Verify Pseudo-Random Run Streams ---
        enable <= 1'b1;
        $display("[SIM] Running 4-bit and 8-bit parallel PRBS streams...");
        
        // Let the 4-bit array complete its maximal cycle bounds (2^4 - 1 = 15 states)
        repeat (20) @(posedge clk);

        // --- Scenario 2: Verify Clock Enable Halting Behavior ---
        enable <= 1'b0;
        $display("[SIM] Lowering enable line. Registers must freeze state values.");
        repeat (5) @(posedge clk);

        // --- Scenario 3: Resume to check high-bit width distributions ---
        enable <= 1'b1;
        repeat (30) @(posedge clk);

        $finish;
    end

endmodule