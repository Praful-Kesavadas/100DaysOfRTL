`timescale 1ns / 1ps

module tb_shift_reg;

    reg clk;
    reg nreset;
    reg load;
    reg serial_in;
    wire [3:0] data_parallel;
    wire serial_out;

    shift_reg uut (.clk(clk), .nreset(nreset), .load(load), .serial_in(serial_in), .data_parallel(data_parallel), .serial_out(serial_out));

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // --- Test Case 1: Asynchronous Clear Initialization ---
        nreset = 1'b0; load = 1'b0; serial_in = 1'b0; #12;
        
        // --- Test Case 2: Release Reset with Load Disabled ---
        nreset = 1'b1;
        serial_in = 1'b1; #10; // Crosses clock edge; array must remain 4'b0000
        
        // --- Test Case 3: Clocking in Serial Stream "4'b1011" (LSB First) ---
        load = 1'b1;
        
        serial_in = 1'b1; #10; // Edge 1: data_parallel becomes 4'b1000
        serial_in = 1'b1; #10; // Edge 2: data_parallel becomes 4'b1100
        serial_in = 1'b0; #10; // Edge 3: data_parallel becomes 4'b0110
        serial_in = 1'b1; #10; // Edge 4: data_parallel becomes 4'b1011
        
        // --- Test Case 4: Hold Bus State ---
        load = 1'b0;
        serial_in = 1'b0; #20; // Holds 4'b1011 over multiple cycles
        
        // --- Test Case 5: Mid-Cycle Reset Drop ---
        #3;
        nreset = 1'b0; #10;
        
        $finish;
    end

endmodule