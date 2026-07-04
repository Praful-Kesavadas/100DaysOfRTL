`timescale 1ns / 1ps

module tb_clk_divider_odd;

    reg clk_in;
    reg nreset;
    reg start;
    wire clk_out;

    clk_divider_odd #(.DIVIDE_BY(3)) uut (
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
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // --- System Power-On Reset Release ---
        nreset = 1'b0; start = 1'b0; #12;
        nreset = 1'b1; 
        
        @(posedge clk_in); 
        start <= 1'b1; // Driven synchronously!
        
        #150; 
        
        @(posedge clk_in);
        start <= 1'b0; 
        #20;
        $finish;
    end

endmodule