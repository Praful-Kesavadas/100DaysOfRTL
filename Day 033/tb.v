`timescale 1ns / 1ps

module tb_traffic_controller;

    reg clk;
    reg nreset;
    wire [2:0] NS_light;
    wire [2:0] EW_light;

    traffic_controller #(
        .YELLOW_CYCLE(3),
        .RED_CYCLE(10) 
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .NS_light(NS_light),
        .EW_light(EW_light)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        nreset = 1'b0; #25;
        nreset = 1'b1; // Release reset and watch the timed cycles flow
        
        #300; // Simulate long enough to see multiple complete light rotations
        $finish;
    end

endmodule