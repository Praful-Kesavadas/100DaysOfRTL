`timescale 1ns / 1ps

module tb_parallel_load_reg;

    reg clk;
    reg nreset;
    reg load;
    reg [3:0] data_in;
    wire [3:0] q;

    // Instantiate Device Under Test
    parallel_load_reg uut (
        .clk(clk),
        .nreset(nreset),
        .load(load),
        .data_in(data_in),
        .q(q)
    );

    // 100 MHz System Clock (10ns period)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        // Open VCD trace file pipeline
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // --- Test Case 1: Active-Low Power-On Reset ---
        nreset = 1'b0; load = 1'b0; data_in = 4'h0; #12;
        
        // --- Test Case 2: Release Reset with Load Disabled (load = 0) ---
        // External data changes, but register must ignore it and hold 4'h0
        nreset = 1'b1;
        data_in = 4'hA; #10; // Crosses 15ns rising clock edge
        data_in = 4'h5; #10; // Crosses 25ns rising clock edge
        
        // --- Test Case 3: Enable Parallel Load (load = 1) ---
        // Register must capture the parallel bus values precisely on the clock edge
        load = 1'b1;
        data_in = 4'hC; #10; // Crosses 35ns edge -> q latches 4'hC
        data_in = 4'h7; #10; // Crosses 45ns edge -> q latches 4'h7
        
        // --- Test Case 4: Synchronous Hold Verification ---
        // Drop load pin mid-cycle. Q must lock onto 4'h7 even when data_in changes.
        load = 1'b0; 
        data_in = 4'hE; #10; // Crosses 55ns edge -> q holds 4'h7
        data_in = 4'h3; #10; // Crosses 65ns edge -> q holds 4'h7
        
        // --- Test Case 5: Emergency Asynchronous Reset Strike ---
        #2; // Advance mid-cycle to 77ns
        nreset = 1'b0; // Q must drop to 0 instantly without waiting for 75ns or 85ns clock edges
        #13;
        
        $finish;
    end

endmodule