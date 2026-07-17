`timescale 1ns / 1ps

module tb_gcd_calculator;

    parameter WIDTH = 8;

    // Testbench Stimulus Nets
    reg [WIDTH-1:0] A, B;
    reg             clk;
    reg             nreset;
    reg             start;

    // Output Monitoring Nets
    wire [WIDTH-1:0] gcd;
    wire             valid;

    // Instantiate Unit Under Test
    gcd_calculator #(.WIDTH(WIDTH)) uut (
        .A(A),
        .B(B),
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .gcd(gcd),
        .valid(valid)
    );

    // Generate 100MHz System Clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Automated Verification Task
    task verify_gcd(input [WIDTH-1:0] val_A, input [WIDTH-1:0] val_B);
        begin
            @(posedge clk);
            A = val_A;
            B = val_B;
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            
            @(posedge valid);
            $display("[TEST] Inputs: A=%0d, B=%0d | Computed GCD Result=%0d", val_A, val_B, gcd);
            #20; // Observation spacing window
        end
    endtask

    initial begin
        // Setup Waveform Logs for Day 40 Visual Post
        $dumpfile("dump.vcd");
        $dumpvars(0);

        nreset = 1'b0;
        start  = 1'b0;
        A      = 0;
        B      = 0;
        #20;
        nreset = 1'b1;
        #20;

        $display("--------------------------------------------------");
        $display("STARTING ALGORITHMIC GCD HARDWARE CALCULATOR TESTS");
        $display("--------------------------------------------------");

        // Test Scenario 1: Standard Variable-Latency Subtraction Path (14 and 4 -> GCD=2)
        verify_gcd(8'd14, 8'd4);

        // Test Scenario 2: High Latency Unbalanced Inputs (100 and 5 -> GCD=5)
        verify_gcd(8'd100, 8'd5);

        // Test Scenario 3: Identical Inputs -> 1 Cycle Compute Finish (9 and 9 -> GCD=9)
        verify_gcd(8'd9, 8'd9);

        // Test Scenario 4: Zero Bypass Bound Check A (0 and 25 -> GCD=25)
        verify_gcd(8'd0, 8'd25);

        // Test Scenario 5: Zero Bypass Bound Check B (42 and 0 -> GCD=42)
        verify_gcd(8'd42, 8'd0);

        // Test Scenario 6: Coprime Elements Evaluation (17 and 13 -> GCD=1)
        verify_gcd(8'd17, 8'd13);

        $display("--------------------------------------------------");
        $display("ALL ARITHMETIC HARDWARE TESTS COMPLETED.");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule