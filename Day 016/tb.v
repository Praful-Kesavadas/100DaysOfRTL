`timescale 1ns / 1ps

module tb_d_latch;

    reg d, en;
    wire q;

    wire [95:0] status;
    assign status = (en ? "TRANSPARENT" : "LATCHED/HOLD");
    d_latch uut (
        .d(d),
        .en(en),
        .q(q)
    );

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
        $monitor("Time = %0d ns | Enable(EN) = %b | Data_In(D) = %b | Output(Q) = %b | Status = %s", 
                 $time, en, d, q, status);
    end

    initial begin
        // --- Initialize Inputs at Time Zero ---
        en = 1'b0; d = 1'b0; #10;
        
        // --- Test Case 1: Change Data While Latched (EN=0) ---
        // Q must completely ignore D transitions and remain 0
        d = 1'b1; #5;
        d = 1'b0; #5;
        
        // --- Test Case 2: Open Latch/Enable Transparency (EN=1) ---
        // Q must mirror D immediately without waiting for any edge
        en = 1'b1; #5;  // Q drops open, hits 0
        d = 1'b1;  #10; // Q instantly rises to 1
        d = 1'b0;  #10; // Q instantly falls to 0
        d = 1'b1;  #5;  // Q instantly rises to 1
        
        // --- Test Case 3: Close Latch Mid-Cycle (EN=0) ---
        // Lock in the data while D is high. Q must hold '1' regardless of D updates.
        en = 1'b0; #5;
        d = 1'b0;  #10; // D drops to 0, but Q must rigidly hold on to 1!
        d = 1'b1;  #10;
        
        // --- Test Case 4: Flush and Reset ---
        en = 1'b1; #5;  // Opens up, passes D=1
        d = 1'b0;  #5;  // Passes D=0
        en = 1'b0; #10; // Closes up, holding 0
        
        $display("--- Day 16 Transparent D-Latch Verification Complete ---");
        $finish;
    end

endmodule