`timescale 1ns / 1ps

module tb_csa_multiplier_matrix();

    parameter CLK_PERIOD = 10;
    parameter DATA_WIDTH = 8; 

    reg                      clk;
    reg                      nreset;
    reg                      start;
    reg  [DATA_WIDTH-1:0]    A, B;
    wire [2*DATA_WIDTH-1:0]  result;
    wire                     valid;

    integer errors = 0;
    integer i;

    // Instantiate Registered CSA Multiplier Core
    csa_multiplier #(
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .A(A),
        .B(B),
        .result(result),
        .valid(valid)
    );

    // 100 MHz Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk    = 0;
        nreset = 0;
        start  = 0;
        A      = 0;
        B      = 0;

        #(CLK_PERIOD * 2);
        nreset = 1;
        #(CLK_PERIOD);

        $display("\n====================================================");
        $display("   DAY 63: REGISTERED %0d-BIT CSA MULTIPLIER VERIFICATION", DATA_WIDTH);
        $display("====================================================\n");

        // TEST 1: 13 * 11 = 143
        @(negedge clk);
        start = 1; A = 13; B = 11;
        @(negedge clk);
        start = 0;

        wait(valid); #1;
        if (result === 143)
            $display("[PASS] 13 * 11 = %0d", result);
        else begin
            $display("[FAIL] Expected 143, Got %0d", result);
            errors = errors + 1;
        end

        // TEST 2: Max Unsigned (255 * 255 = 65025)
        @(negedge clk);
        start = 1; A = 255; B = 255;
        @(negedge clk);
        start = 0;

        wait(valid); #1;
        if (result === 65025)
            $display("[PASS] 255 * 255 = %0d", result);
        else begin
            $display("[FAIL] Expected 65025, Got %0d", result);
            errors = errors + 1;
        end

        // TEST 3: Random Vector Matrix Sweep
        for (i = 0; i < 10; i = i + 1) begin
            @(negedge clk);
            start = 1;
            A = $urandom_range(0, (1<<DATA_WIDTH)-1);
            B = $urandom_range(0, (1<<DATA_WIDTH)-1);
            @(negedge clk);
            start = 0;

            wait(valid); #1;
            if (result == (A * B))
                $display("[PASS] Random %0d * %0d = %0d", A, B, result);
            else begin
                $display("[FAIL] Random %0d * %0d = %0d (Expected %0d)", A, B, result, A*B);
                errors = errors + 1;
            end
        end

        $display("\n====================================================");
        if (errors == 0) $display(" ALL REGISTERED CSA MULTIPLIER TESTS PASSED!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");

        #20;
        $finish;
    end

endmodule