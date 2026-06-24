module tb_dff();
    reg clk, nreset;
    reg d;
    wire q;
    
    dff dut(.d(d), .clk(clk), .nreset(nreset), .q(q));

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
    end
    always #5 clk = ~clk;
    initial begin
        clk = 1'b0;
        // --- Test Case 1: Active-Low Power-on Reset ---
        nreset = 1'b0; d = 1'd0; #12; 
        
        // --- Test Case 2: Release Reset Mid-Cycle ---
        // Releases reset at 12ns. Next positive clock edge occurs at 15ns.
        nreset = 1'b1; 
        d = 1'b1;   #10; // Q captures 5 at 15ns tick
        d = 1'b0;  #10; // Q captures 12 at 25ns tick
        d = 1'b1;   #10; // Q captures 3 at 35ns tick
        
        // --- Test Case 3: Mid-Cycle Asynchronous Reset Strike ---
        // Clock rises at 45ns (Q stays 3). We strike reset at 38ns mid-cycle.
        #7 nreset = 1'b0; // Q must instantly drop to 0 at 38ns without waiting for 45ns!
        #7; // Hold reset active across the 45ns clock boundary
        
        // --- Test Case 4: Recovery Transition ---
        nreset = 1'b1;
        d = 1'd0;   #10; // Q captures 7 at 55ns tick
        
        $finish;
    end
endmodule