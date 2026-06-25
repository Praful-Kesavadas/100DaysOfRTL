module tb_jkff();
    reg j, k, clk, nreset;
    wire q, q_bar;

    jkff uut(.j(j), .k(k), .clk(clk), .nreset(nreset), .q(q), .q_bar(q_bar));

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
    end

    initial begin
        // --- Test Case 1: Initial Power-On Asynchronous Reset ---
        nreset = 1'b0; j = 1'b0; k = 1'b0; #12;
        
        // --- Test Case 2: Release Reset to Hold Mode (00) ---
        nreset = 1'b1; #13; // Crosses 15ns edge -> Q cleanly holds 0
        
        // --- Test Case 3: Set State Transition (10) ---
        j = 1'b1; k = 1'b0; #10; // Crosses 35ns edge -> Q latches 1
        
        // --- Test Case 4: High State Hold Check (00) ---
        j = 1'b0; k = 1'b0; #10; // Crosses 45ns edge -> Q maintains 1
        
        // --- Test Case 5: Clear State Transition (01) ---
        j = 1'b0; k = 1'b1; #10; // Crosses 55ns edge -> Q drops to 0
        
        // --- Test Case 6: Continuous Toggle Mode Sweeps (11) ---
        j = 1'b1; k = 1'b1; 
        #10; // Crosses 65ns edge -> Q toggles 0 -> 1
        #10; // Crosses 75ns edge -> Q toggles 1 -> 0
        #10; // Crosses 85ns edge -> Q toggles 0 -> 1
        
        // --- Test Case 7: Asynchronous Reset Interruption Override ---
        #3; // Advance to 98ns mid-cycle
        nreset = 1'b0; // Q must instantly drop to 0 without waiting for 105ns edge!
        #7;
        
        $display("--- Day 18 JK Flip-Flop Verification Complete ---");
        $finish;
    end
endmodule