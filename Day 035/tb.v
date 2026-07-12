`timescale 1ns / 1ps

module tb_digital_lock;

    // Inputs
    reg clk;
    reg nreset;
    reg done_in;
    reg admin_reset_signal;
    reg passcode_in;
    reg [3:0] pin_in;
    reg [3:0] passcode;

    // Outputs
    wire [1:0] tries_left;
    wire lock_open;

    // Instantiate Device Under Test
    digital_lock uut (
        .clk(clk),
        .nreset(nreset),
        .done_in(done_in),
        .admin_reset_signal(admin_reset_signal),
        .passcode_in(passcode_in),
        .pin_in(pin_in),
        .passcode(passcode),
        .tries_left(tries_left),
        .lock_open(lock_open)
    );

    // 100 MHz reference clock generation (10ns period)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        // Initialize VCD dump for waveform analysis
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_digital_lock);

        // --- Master Hardware Reset Init ---
        nreset = 1'b0; done_in = 1'b0; admin_reset_signal = 1'b0;
        passcode_in = 1'b0; pin_in = 4'b0000; passcode = 4'b0000;
        #20;
        nreset = 1'b1; 
        repeat(2) @(posedge clk);

        // =================================================================
        // SCENARIO 1: Verify Default Factory PIN (4'b0000) Unlocks System
        // =================================================================
        pin_in = 4'b0000;
        @(posedge clk);
        done_in <= 1'b1; // FIXED: Non-blocking driving prevents simulator race
        @(posedge clk);
        done_in <= 1'b0; // FIXED: Non-blocking release
        repeat(4) @(posedge clk); // Machine transitions to SUCCESS (State 5)

        // =================================================================
        // SCENARIO 2: Relock and Execute 1 Incorrect Attempt
        // =================================================================
        // First exit SUCCESS state by pulsing done_in
        done_in <= 1'b1; @(posedge clk); done_in <= 1'b0; @(posedge clk); // Back to INPUT_PIN
        
        pin_in = 4'b1111; // Invalid code choice
        @(posedge clk);
        done_in <= 1'b1;
        @(posedge clk);
        done_in <= 1'b0;
        repeat(4) @(posedge clk); // Machine transitions to ONE_FAIL (State 1)

        // =================================================================
        // SCENARIO 3: Submit Correct Attempt (0000) to Recover
        // =================================================================
        pin_in = 4'b0000; 
        @(posedge clk);
        done_in <= 1'b1;
        @(posedge clk);
        done_in <= 1'b0;
        repeat(4) @(posedge clk); // Machine transitions back to SUCCESS (State 5)

        // =================================================================
        // SCENARIO 4: Admin Pin Reset sequence while Unlocked
        // =================================================================
        admin_reset_signal <= 1'b1; // Drive administrative override line high
        @(posedge clk);
        admin_reset_signal <= 1'b0; // Clear line
        repeat(2) @(posedge clk); // Machine rests inside RESET_PIN (State 4)

        passcode = 4'b1101; // Assign new secure combination code
        @(posedge clk);
        passcode_in <= 1'b1; // Commit code update strobe
        @(posedge clk);
        passcode_in <= 1'b0;
        repeat(4) @(posedge clk); // Core re-normalizes back to INPUT_PIN (State 0)

        // =================================================================
        // SCENARIO 5: Verify the Newly Configured PIN (4'b1101) Opens Lock
        // =================================================================
        pin_in = 4'b1101;
        @(posedge clk);
        done_in <= 1'b1;
        @(posedge clk);
        done_in <= 1'b0;
        repeat(4) @(posedge clk); // Machine transitions to SUCCESS (State 5)

        // Exit success state to prepare for lockout test sequence
        done_in <= 1'b1; @(posedge clk); done_in <= 1'b0; repeat(2) @(posedge clk);

        // =================================================================
        // SCENARIO 6: Induce 3 Sequential Failures to Force Lockout Block
        // =================================================================
        // --- Failure attempt 1 ---
        pin_in = 4'b0000; @(posedge clk); done_in <= 1'b1; @(posedge clk); done_in <= 1'b0;
        repeat(3) @(posedge clk); // Drops to ONE_FAIL (State 1)

        // --- Failure attempt 2 ---
        pin_in = 4'b0001; @(posedge clk); done_in <= 1'b1; @(posedge clk); done_in <= 1'b0;
        repeat(3) @(posedge clk); // Drops to TWO_FAIL (State 2)

        // --- Failure attempt 3 ---
        pin_in = 4'b0010; @(posedge clk); done_in <= 1'b1; @(posedge clk); done_in <= 1'b0;
        repeat(4) @(posedge clk); // Drops to INACTIVE / Brute lockout active (State 3)

        // =================================================================
        // SCENARIO 7: Submit 2 Entry Attempts Post-Lockout (Verify Immunity)
        // =================================================================
        // Entry Attempt 1: Arbitrary Bad Entry Attempt
        pin_in = 4'b0101;
        @(posedge clk);
        done_in <= 1'b1;
        @(posedge clk);
        done_in <= 1'b0;
        repeat(3) @(posedge clk); // Verify FSM stays entirely frozen in State 3, lock remains zero

        // Entry Attempt 2: Attempting Valid Passcode Vector (Still Blocked)
        pin_in = 4'b1101;
        @(posedge clk);
        done_in <= 1'b1;
        @(posedge clk);
        done_in <= 1'b0;
        repeat(4) @(posedge clk); // Confirm lockout cannot be bypassed by correct user codes

        // =================================================================
        // SCENARIO 8: Assert Full Hardware Reset Pin to Default System
        // =================================================================
        nreset = 1'b0; // Active low reset asserted at layout level
        repeat(3) @(posedge clk);
        nreset = 1'b1; // Release reset line
        repeat(3) @(posedge clk); // Confirm state drops cleanly back to INPUT_PIN (State 0)

        $finish;
    end

endmodule