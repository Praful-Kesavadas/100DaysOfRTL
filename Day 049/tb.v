`timescale 1ns / 1ps

module tb_fixed_priority_arbiter;

    // Parameters
    parameter NUM_REQS   = 8;
    parameter CLK_PERIOD = 10; // 100 MHz System Clock

    // Testbench Signals
    reg                  clk;
    reg                  nreset;
    reg                  grant_ready;
    reg  [NUM_REQS-1:0]  requests;
    wire [NUM_REQS-1:0]  grant;

    // Error Tracking
    integer errors = 0;

    // Instantiate Unit Under Test (UUT)
    fixed_priority_arbiter #(
        .NUM_REQS(NUM_REQS)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .grant_ready(grant_ready),
        .requests(requests),
        .grant(grant)
    );

    // Clock Generation (100 MHz)
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Automated Self-Checking Task
    task check_grant(input [NUM_REQS-1:0] expected_grant, input [10*45:1] test_name);
        begin
            @(posedge clk);
            #1; // Delta delay to sample post-clock edge register updates
            if (grant !== expected_grant) begin
                $display("[FAIL] %0s | Expected: 8'b%b, Got: 8'b%b", test_name, expected_grant, grant);
                errors = errors + 1;
            end else begin
                $display("[PASS] %0s | Grant: 8'b%b", test_name, grant);
            end
        end
    endtask

    // Stimulus Process
    initial begin
        // Waveform Dump for GTKWave
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // Initialize Signals
        clk         = 0;
        nreset      = 0;
        grant_ready = 1;
        requests    = {NUM_REQS{1'b0}};

        // -------------------------------------------------------------
        // STEP 1: Reset Assertion
        // -------------------------------------------------------------
        #(CLK_PERIOD * 2);
        nreset = 1; // Release reset
        $display("\n====================================================");
        $display("   DAY 49: FIXED PRIORITY ARBITER VERIFICATION");
        $display("====================================================\n");

        if (grant !== 8'b0000_0000) begin
            $display("[FAIL] Reset State Verification Failed! Got: %b", grant);
            errors = errors + 1;
        end else begin
            $display("[PASS] Reset State Verification Successful.");
        end

        // -------------------------------------------------------------
        // STEP 2: Single Master Requests
        // -------------------------------------------------------------
        requests = 8'b0000_1000; // Only Agent 3 requests
        check_grant(8'b0000_1000, "Test 1: Single Request (Agent 3)");

        // -------------------------------------------------------------
        // STEP 3: Multi-Master Priority Resolution (Lowest index wins)
        // -------------------------------------------------------------
        requests = 8'b0010_0100; // Agent 2 & Agent 5 requesting simultaneously
        check_grant(8'b0000_0100, "Test 2: Priority Resolution (Agent 2 > Agent 5)");

        requests = 8'b1001_0011; // Agents 0, 1, 4, 7 requesting -> Agent 0 MUST win
        check_grant(8'b0000_0001, "Test 3: Absolute Dominance (Agent 0 Wins)");

        // -------------------------------------------------------------
        // STEP 4: Multi-Cycle Bus Locking (`grant_ready = 0`)
        // -------------------------------------------------------------
        // Step 4a: Agent 2 requests and wins grant normally
        requests    = 8'b0000_0100; 
        grant_ready = 1;
        @(posedge clk); #1; // Agent 2 now holds grant (8'b0000_0100)

        // Step 4b: Lock the bus (Agent 2 starts a 3-cycle burst)
        grant_ready = 0;
        requests    = 8'b0000_0101; // Agent 0 (higher priority) demands the bus!
        
        // Verification: Grant MUST NOT change to Agent 0 while grant_ready == 0
        check_grant(8'b0000_0100, "Test 4A: Bus Lock Active (Agent 0 Blocked)");
        check_grant(8'b0000_0100, "Test 4B: Bus Lock Cycle 2 (Agent 2 Holds)");

        // Step 4c: Release the bus (`grant_ready = 1`)
        grant_ready = 1;
        // On next clock edge, Agent 0 pre-empts and receives grant
        check_grant(8'b0000_0001, "Test 4C: Bus Released -> Agent 0 Pre-empts");

        // -------------------------------------------------------------
        // STEP 5: Idle Bus State
        // -------------------------------------------------------------
        requests = 8'b0000_0000;
        check_grant(8'b0000_0000, "Test 5: Zero Requests -> Bus Idle");

        // -------------------------------------------------------------
        // Test Summary
        // -------------------------------------------------------------
        $display("\n====================================================");
        if (errors == 0) begin
            $display("  ALL TESTS PASSED (0 ERRORS) <<<  ");
        end else begin
            $display("  VERIFICATION FAILED (%0d ERRORS) <<<  ", errors);
        end
        $display("====================================================\n");

        $finish;
    end

endmodule