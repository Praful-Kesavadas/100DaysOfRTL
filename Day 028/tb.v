`timescale 1ns / 1ps

module tb_pwm_modulator;

    parameter TEST_WIDTH = 8;

    reg clk;
    reg nreset;
    reg start;
    reg [TEST_WIDTH-1:0] duty_cycle;
    wire pwm_out;

    pwm_modulator #(.WIDTH(TEST_WIDTH)) uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .duty_cycle(duty_cycle),
        .pwm_out(pwm_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // --- Stage 1: Asynchronous Clear Initialization ---
        nreset = 1'b0; start = 1'b0; duty_cycle = 8'd0; #12;
        nreset = 1'b1; #10;
        start = 1'b1;

        // --- Stage 2: Verify Strict 0% Boundary State ---
        duty_cycle = 8'd0;
        #3000; // Allow a full counter sweep (2560ns) to confirm flat low line

        // --- Stage 3: Verify 25% Duty Cycle State ---
        // 64 / 256 = 25% High pulse width tracking
        @(posedge clk);
        duty_cycle = 8'd64;
        #3000;

        // --- Stage 4: Verify Absolute 100% Boundary State ---
        @(posedge clk);
        duty_cycle = 8'hFF;
        #3000; // Confirm flat high saturation line

        start = 1'b0; #10;
        $finish;
    end

endmodule