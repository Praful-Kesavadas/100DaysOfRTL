`timescale 1ns / 1ps

module tb_pipelined_multiplier();

    parameter WIDTH      = 8;
    parameter CLK_PERIOD = 10;

    reg                 clk;
    reg                 nreset;
    reg                 valid_in;
    reg  [WIDTH-1:0]    a, b;
    wire [2*WIDTH-1:0]  product;
    wire                valid_out;

    integer errors = 0;

    // Instantiate Module
    pipelined_multiplier #(
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .valid_in(valid_in),
        .a(a),
        .b(b),
        .product(product),
        .valid_out(valid_out)
    );

    // 100 MHz Clock Generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk      = 0;
        nreset   = 0;
        valid_in = 0;
        a        = 0;
        b        = 0;

        // Apply Reset
        #(CLK_PERIOD * 2);
        nreset = 1;
        #(CLK_PERIOD);

        $display("\n====================================================");
        $display("   DAY 57: EXPLICIT PIPELINED MULTIPLIER VERIFICATION");
        $display("====================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Single Pulse Check (2-Cycle Latency)
        // -------------------------------------------------------------
        $display("--- TEST 1: Checking 2-Cycle Pipeline Latency ---");
        @(negedge clk);
        valid_in = 1; a = 8'd25; b = 8'd15; // 25 * 15 = 375

        @(posedge clk); #1; // Posedge 1: Stage 1 fills
        if (!valid_out) begin
            $display("[PASS] Cycle 1: Stage 1 loaded (`valid_out` is 0).");
        end else begin
            $display("[FAIL] Cycle 1: `valid_out` asserted early!");
            errors = errors + 1;
        end

        @(negedge clk); valid_in = 0;

        @(posedge clk); #1; // Posedge 2: Stage 2 completes
        if (valid_out && product === 16'd375) begin
            $display("[PASS] Cycle 2: `valid_out` = 1, Product = %0d (Expected 375).", product);
        end else begin
            $display("[FAIL] Cycle 2: Result mismatch! Got %0d, Exp 375", product);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 2: Burst Back-to-Back Streaming
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Continuous Back-to-Back Streaming ---");
        @(negedge clk); valid_in = 1; a = 8'd5;   b = 8'd5;   // 25
        @(negedge clk); valid_in = 1; a = 8'd255; b = 8'd255; // 65025 (Max 8-bit mult)

        @(posedge clk); #1; // 5*5 ready at output
        if (valid_out && product == 16'd25) begin
            $display("[PASS] Stream 1 Output = %0d (5x5)", product);
        end else begin
            $display("[FAIL] Stream 1 Mismatch! Got %0d, Exp 25", product);
            errors = errors + 1;
        end

        @(negedge clk); valid_in = 1; a = 8'd128; b = 8'd2;   // 256
        @(posedge clk); #1; // 255*255 ready at output
        if (valid_out && product == 16'd65025) begin
            $display("[PASS] Stream 2 Output = %0d (Max 8-bit Mult: 255x255)", product);
        end else begin
            $display("[FAIL] Stream 2 Mismatch! Got %0d, Exp 65025", product);
            errors = errors + 1;
        end

        @(posedge clk); #1; // 128*2 ready at output
        if (valid_out && product == 16'd256) begin
            $display("[PASS] Stream 3 Output = %0d (128x2)", product);
        end else begin
            $display("[FAIL] Stream 3 Mismatch! Got %0d, Exp 256", product);
            errors = errors + 1;
        end
        @(negedge clk); valid_in = 0;

        // SUMMARY
        $display("\n====================================================");
        if (errors == 0) $display(" ALL PIPELINED MULTIPLIER TESTS PASSED!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");

        $finish;
    end

endmodule