`timescale 1ns / 1ps

module tb_uni_shift_reg;

    reg clk;
    reg nreset;
    reg serial_in_ls;
    reg serial_in_rs;
    reg [3:0] parallel_load;
    reg [1:0] mode;
    wire [3:0] q;

    uni_shift_reg uut (
        .clk(clk),
        .nreset(nreset),
        .serial_in_ls(serial_in_ls),
        .serial_in_rs(serial_in_rs),
        .parallel_load(parallel_load),
        .mode(mode),
        .q(q)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // --- Setup Initial Idle States ---
        nreset = 1'b0; mode = 2'b00; 
        serial_in_ls = 1'b0; serial_in_rs = 1'b0; parallel_load = 4'h0; #12;
        
        // --- Test Case 1: Parallel Load Mode (mode = 11) ---
        nreset = 1'b1;
        mode = 2'b11; parallel_load = 4'hA; #10; // Edge at 15ns: Q latches 4'b1010
        
        // --- Test Case 2: Synchronous Hold Mode (mode = 00) ---
        mode = 2'b00; parallel_load = 4'hF; #20; // Crosses 25ns and 35ns edges: Q must hold 4'b1010
        
        // --- Test Case 3: Shift Right Mode (mode = 01) ---
        // Feed in a stream of 1s into the MSB position
        mode = 2'b01; serial_in_rs = 1'b1;
        #10; // Edge 45ns: Q becomes 4'b1101
        #10; // Edge 55ns: Q becomes 4'b1110
        
        // --- Test Case 4: Synchronous Hold Mode (mode = 00) ---
        mode = 2'b00; #10; // Edge 65ns: Q holds 4'b1110
        
        // --- Test Case 5: Shift Left Mode (mode = 10) ---
        // Feed in a stream of 0s into the LSB position
        mode = 2'b10; serial_in_ls = 1'b0;
        #10; // Edge 75ns: Q becomes 4'b1100
        #10; // Edge 85ns: Q becomes 4'b1000
        
        // --- Test Case 6: Mid-Cycle Asynchronous Reset Override ---
        #3;  // Advance to 98ns mid-cycle
        nreset = 1'b0; #12; // Q must instantly clear to 0 without waiting for 105ns edge
        
        $finish;
    end

endmodule