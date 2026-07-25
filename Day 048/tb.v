`timescale 1ns / 1ps

module tb_pic_core();

    localparam NUM_IRQS    = 8;
    localparam ADDR_WIDTH  = 16;
    localparam BASE_VECTOR = 16'h1000;

    reg                   clk;
    reg                   nreset;
    reg  [NUM_IRQS-1:0]   irq_req;
    reg                   imr_write;
    reg  [NUM_IRQS-1:0]   imr_in;
    reg                   irq_ack;
    reg                   eoi;

    wire                  irq_out;
    wire [ADDR_WIDTH-1:0] irq_vector;

    integer               error_count = 0;

    // Instantiate UUT
    pic_core #(
        .NUM_IRQS(NUM_IRQS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BASE_VECTOR(BASE_VECTOR)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .irq_req(irq_req),
        .imr_write(imr_write),
        .imr_in(imr_in),
        .irq_ack(irq_ack),
        .eoi(eoi),
        .irq_out(irq_out),
        .irq_vector(irq_vector)
    );

    // 100 MHz Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test Sequencer
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        nreset   = 0;
        irq_req   = 0;
        imr_write = 0;
        imr_in    = 0;
        irq_ack   = 0;
        eoi       = 0;

        #20;
        nreset = 1;
        #10;

        // --------------------------------------------------------------------
        // TEST 1: Basic IRQ Assertion & Vector Calculation (IRQ 3)
        // Expected Vector: 16'h1000 + (3 * 4) = 16'h100C
        // --------------------------------------------------------------------
        $display("\n--- TEST 1: Single IRQ 3 Request ---");
        @(negedge clk);
        irq_req = 8'b0000_1000; // IRQ 3
        @(negedge clk);
        irq_req = 0; // Pulse input

        @(posedge clk); #1;
        if (irq_out === 1'b1 && irq_vector === 16'h100C) begin
            $display("--> PASS: IRQ 3 asserted cleanly with vector 16'h%h", irq_vector);
        end else begin
            $display("--> FAIL: Expected Vector 16'h100C, Got 16'h%h (irq_out=%b)", irq_vector, irq_out);
            error_count = error_count + 1;
        end

        // Acknowledge IRQ 3
        @(negedge clk); irq_ack = 1;
        @(negedge clk); irq_ack = 0;

        // --------------------------------------------------------------------
        // TEST 2: Nested Priority Pre-emption Check
        // While IRQ 3 is in-service (ISR[3]=1):
        //   a) IRQ 5 arrives -> Should BE BLOCKED (lower priority)
        //   b) IRQ 1 arrives -> Should PRE-EMPT (higher priority)
        // --------------------------------------------------------------------
        $display("\n--- TEST 2: Priority Pre-emption Check ---");
        
        // Assert IRQ 5 (lower priority than IRQ 3 in service)
        @(negedge clk); irq_req = 8'b0010_0000;
        @(negedge clk); irq_req = 0;
        
        @(posedge clk); #1;
        if (irq_out === 1'b0) begin
            $display("--> PASS: IRQ 5 successfully blocked while IRQ 3 is in-service.");
        end else begin
            $display("--> FAIL: IRQ 5 wrongly pre-empted IRQ 3!");
            error_count = error_count + 1;
        end

        // Assert IRQ 1 (higher priority than IRQ 3 in service)
        @(negedge clk); irq_req = 8'b0000_0010;
        @(negedge clk); irq_req = 0;

        @(posedge clk); #1;
        if (irq_out === 1'b1 && irq_vector === 16'h1004) begin // 16'h1000 + 4 = 16'h1004
            $display("--> PASS: High-priority IRQ 1 successfully pre-empted IRQ 3! Vector: 16'h%h", irq_vector);
        end else begin
            $display("--> FAIL: High priority pre-emption failed!");
            error_count = error_count + 1;
        end

        // ACK IRQ 1, send EOI for IRQ 1
        @(negedge clk); irq_ack = 1;
        @(negedge clk); irq_ack = 0;
        @(negedge clk); eoi     = 1; // Clears IRQ 1 from ISR
        @(negedge clk); eoi     = 0;

        // EOI for IRQ 3
        @(negedge clk); eoi     = 1; // Clears IRQ 3 from ISR
        @(negedge clk); eoi     = 0;

        // Now pending IRQ 5 should immediately output!
        @(posedge clk); #1;
        if (irq_out === 1'b1 && irq_vector === 16'h1014) begin // 16'h1000 + 20 = 16'h1014
            $display("--> PASS: Pending IRQ 5 now serviced after higher IRQs completed. Vector: 16'h%h", irq_vector);
        end else begin
            $display("--> FAIL: Deferred IRQ 5 failed to trigger!");
            error_count = error_count + 1;
        end

        // ACK & Clear IRQ 5
        @(negedge clk); irq_ack = 1;
        @(negedge clk); irq_ack = 0;
        @(negedge clk); eoi     = 1;
        @(negedge clk); eoi     = 0;

        // --------------------------------------------------------------------
        // TEST 3: Interrupt Masking (IMR) Test
        // Mask IRQ 0 via IMR register write, then request IRQ 0
        // --------------------------------------------------------------------
        $display("\n--- TEST 3: Interrupt Mask Register (IMR) ---");
        @(negedge clk);
        imr_write = 1;
        imr_in    = 8'b0000_0001; // Mask IRQ 0
        @(negedge clk);
        imr_write = 0;

        @(negedge clk); irq_req = 8'b0000_0001; // Request IRQ 0
        @(negedge clk); irq_req = 0;

        @(posedge clk); #1;
        if (irq_out === 1'b0) begin
            $display("--> PASS: Masked IRQ 0 was completely ignored.");
        end else begin
            $display("--> FAIL: Masked IRQ 0 triggered an interrupt!");
            error_count = error_count + 1;
        end

        // SUMMARY
        $display("\n==================================================");
        if (error_count == 0) $display(" ALL PIC CORE TESTS PASSED SUCCESSFULLY!");
        else                  $display(" TESTBENCH FAILED WITH %0d ERROR(S)", error_count);
        $display("==================================================\n");

        $finish;
    end

endmodule