`timescale 1ns / 1ps

module tb_round_robin_arbiter();

    parameter NUM_REQS   = 8;
    parameter CLK_PERIOD = 10;

    reg                  clk;
    reg                  nreset;
    reg                  grant_ready;
    reg  [NUM_REQS-1:0]  requests;
    wire [NUM_REQS-1:0]  grant;

    integer errors = 0;

    // Instantiate UUT
    round_robin_arbiter #(
        .NUM_REQS(NUM_REQS)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .grant_ready(grant_ready),
        .requests(requests),
        .grant(grant)
    );

    // Clock Generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Checking Task
    task check_grant(input [NUM_REQS-1:0] exp_grant, input [10*45:1] test_name);
        begin
            @(posedge clk); #1;
            if (grant !== exp_grant) begin
                $display("[FAIL] %0s | Exp: 8'b%b, Got: 8'b%b", test_name, exp_grant, grant);
                errors = errors + 1;
            end else begin
                $display("[PASS] %0s | Grant: 8'b%b", test_name, grant);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk         = 0;
        nreset      = 0;
        grant_ready = 1;
        requests    = 0;

        #(CLK_PERIOD * 2);
        nreset = 1;
        #(CLK_PERIOD);

        $display("\n====================================================");
        $display("   DAY 50: ROUND-ROBIN ARBITER VERIFICATION");
        $display("====================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Continuous Contention (Agent 1 & Agent 2 keep requesting)
        // Expected: Should alternate Agent 1 -> Agent 2 -> Agent 1 -> Agent 2
        // -------------------------------------------------------------
        $display("--- TEST 1: Continuous Contention Rotation ---");
        requests = 8'b0000_0110; // Agents 1 and 2 active
        check_grant(8'b0000_0010, "Cycle 1: Agent 1 granted");
        check_grant(8'b0000_0100, "Cycle 2: Agent 2 granted (Round-Robin)");
        check_grant(8'b0000_0010, "Cycle 3: Agent 1 granted (Round-Robin)");

        // -------------------------------------------------------------
        // TEST 2: Priority History Retention Across Idle Gap
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Idle Gap Memory Retention ---");
        requests = 8'b0000_0000; // Bus goes idle
        check_grant(8'b0000_0000, "Cycle 4: Bus Idle (grant = 0)");

        // Now Agents 1 and 3 request simultaneously
        // Since Agent 1 was granted last in Cycle 3, Agent 3 MUST win!
        requests = 8'b0000_1010; // Agents 1 and 3
        check_grant(8'b0000_1000, "Cycle 5: Agent 3 wins over Agent 1 (History Preserved!)");

        // -------------------------------------------------------------
        // TEST 3: Wrap-Around Priority (Agent 7 granted -> wrap to Agent 0)
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Full Wrap-Around Check ---");
        requests = 8'b1000_0001; // Agents 0 and 7
        // Currently Agent 3 was granted last. So Agent 7 should win next.
        check_grant(8'b1000_0000, "Cycle 6: Agent 7 granted");
        
        // Next cycle, Agent 0 should win (wrap-around)
        check_grant(8'b0000_0001, "Cycle 7: Agent 0 granted (Wrap-around)");

        // SUMMARY
        $display("\n====================================================");
        if (errors == 0) $display(" ALL ROUND-ROBIN TESTS PASSED (0 ERRORS)!");
        else             $display(" VERIFICATION FAILED (%0d ERRORS)", errors);
        $display("====================================================\n");

        $finish;
    end

endmodule