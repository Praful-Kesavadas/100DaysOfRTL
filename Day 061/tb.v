`timescale 1ns / 1ps

module tb_dma_controller();

    parameter CLK_PERIOD = 10;
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;

    reg                   clk;
    reg                   nreset;
    reg                   start;
    reg                   irq_ack;
    reg  [ADDR_WIDTH-1:0] src_addr_in;
    reg  [ADDR_WIDTH-1:0] dest_addr_in;
    reg  [15:0]           transfer_len_in;
    reg                   src_inc_in;
    reg                   dest_inc_in;

    wire                  busy;
    wire                  done_irq;
    wire                  error;

    wire                  bus_req;
    wire                  bus_write;
    wire [ADDR_WIDTH-1:0] bus_addr;
    wire [DATA_WIDTH-1:0] bus_wdata;
    reg  [DATA_WIDTH-1:0] bus_rdata;
    reg                   bus_ack;

    // Emulated Dual-Port Memory Maps
    reg [DATA_WIDTH-1:0] sram_src  [0:15];
    reg [DATA_WIDTH-1:0] sram_dest [0:15];
    reg [DATA_WIDTH-1:0] uart_tx_fifo;

    integer errors = 0;
    integer i;

    // Instantiate 5-State DMA Core
    dma_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .irq_ack(irq_ack),
        .src_addr_in(src_addr_in),
        .dest_addr_in(dest_addr_in),
        .transfer_len_in(transfer_len_in),
        .src_inc_in(src_inc_in),
        .dest_inc_in(dest_inc_in),
        .busy(busy),
        .done_irq(done_irq),
        .error(error),
        .bus_req(bus_req),
        .bus_write(bus_write),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_ack(bus_ack)
    );

    // Clock Generator (100 MHz)
    always #(CLK_PERIOD / 2) clk = ~clk;

    // -------------------------------------------------------------
    // MEMORY SLAVE EMULATOR (Responds to bus_req with 1-cycle ack)
    // -------------------------------------------------------------
    always @(posedge clk or negedge nreset) begin
        if (!nreset) begin
            bus_ack      <= 1'b0;
            bus_rdata    <= 32'd0;
            uart_tx_fifo <= 32'd0;
        end else begin
            bus_ack <= 1'b0; // Default de-asserted

            if (bus_req && !bus_ack) begin
                bus_ack <= 1'b1; // Generate 1-cycle acknowledgment

                if (!bus_write) begin // READ OPERATION
                    if (bus_addr >= 32'h1000 && bus_addr < 32'h1040)
                        bus_rdata <= sram_src[(bus_addr - 32'h1000) >> 2];
                end else begin // WRITE OPERATION
                    if (bus_addr >= 32'h2000 && bus_addr < 32'h2040)
                        sram_dest[(bus_addr - 32'h2000) >> 2] <= bus_wdata;
                    else if (bus_addr == 32'h4000)
                        uart_tx_fifo <= bus_wdata; // Fixed Peripheral FIFO
                end
            end
        end
    end

    // -------------------------------------------------------------
    // VERIFICATION SEQUENCER
    // -------------------------------------------------------------
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk             = 0;
        nreset          = 0;
        start           = 0;
        irq_ack         = 0;
        src_addr_in     = 0;
        dest_addr_in    = 0;
        transfer_len_in = 0;
        src_inc_in      = 0;
        dest_inc_in     = 0;

        // Initialize Source Memory Buffer with Known Patterns
        for (i = 0; i < 16; i = i + 1) begin
            sram_src[i]  = 32'hA5A5_0000 + i;
            sram_dest[i] = 32'd0;
        end

        #(CLK_PERIOD * 2);
        nreset = 1;
        #(CLK_PERIOD);

        $display("\n====================================================");
        $display("   5-STATE DMA CONTROLLER CORE VERIFICATION");
        $display("====================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Memory-to-Memory Transfer (SRAM 0x1000 -> SRAM 0x2000)
        // -------------------------------------------------------------
        $display("--- TEST 1: Memory-to-Memory Transfer (4 Words) ---");
        @(negedge clk);
        start           = 1;
        src_addr_in     = 32'h1000;
        dest_addr_in    = 32'h2000;
        transfer_len_in = 16'd4;
        src_inc_in      = 1'b1; // Increment src
        dest_inc_in     = 1'b1; // Increment dest
        @(negedge clk); start = 0;

        wait(done_irq); #1;
        $display("[INFO] Persistent Interrupt Asserted (done_irq = 1)");

        // Verify copied data in destination SRAM
        for (i = 0; i < 4; i = i + 1) begin
            if (sram_dest[i] === sram_src[i])
                $display("[PASS] Word %0d Match: Addr 0x%08h = 0x%08h", i, 32'h2000 + (i*4), sram_dest[i]);
            else begin
                $display("[FAIL] Word %0d Mismatch! Expected 0x%08h, Got 0x%08h", i, sram_src[i], sram_dest[i]);
                errors = errors + 1;
            end
        end

        // Assert Software Acknowledge to Clear Interrupt
        @(negedge clk); irq_ack = 1;
        @(negedge clk); irq_ack = 0; #1;
        if (!done_irq)
            $display("[PASS] Interrupt cleared successfully via irq_ack!");
        else begin
            $display("[FAIL] Interrupt failed to clear after irq_ack!");
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 2: Memory-to-Peripheral Stream (SRAM 0x1000 -> UART 0x4000)
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Memory-to-Peripheral Stream (dest_inc = 0) ---");
        @(negedge clk);
        start           = 1;
        src_addr_in     = 32'h1008; // Point to Word 2
        dest_addr_in    = 32'h4000; // Fixed UART TX FIFO address
        transfer_len_in = 16'd1;
        src_inc_in      = 1'b1;
        dest_inc_in     = 1'b0; // Fixed destination!
        @(negedge clk); start = 0;

        wait(done_irq); #1;
        if (uart_tx_fifo === sram_src[2])
            $display("[PASS] Fixed Address Streaming Match! UART TX FIFO = 0x%08h", uart_tx_fifo);
        else begin
            $display("[FAIL] UART FIFO Mismatch! Expected 0x%08h, Got 0x%08h", sram_src[2], uart_tx_fifo);
            errors = errors + 1;
        end

        @(negedge clk); irq_ack = 1;
        @(negedge clk); irq_ack = 0;

        // -------------------------------------------------------------
        // TEST 3: Zero-Length Transfer Request Safety Check
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Zero-Length Request Safety Check ---");
        @(negedge clk);
        start           = 1;
        transfer_len_in = 16'd0;
        @(negedge clk); start = 0;

        wait(done_irq); #1;
        if (done_irq && !busy)
            $display("[PASS] Zero-length request safely triggered DONE state without bus hang!");
        else begin
            $display("[FAIL] Zero-length handling failed!");
            errors = errors + 1;
        end

        @(negedge clk); irq_ack = 1;
        @(negedge clk); irq_ack = 0;

        // SUMMARY
        $display("\n====================================================");
        if (errors == 0) $display(" ALL 5-STATE DMA CONTROLLER TESTS PASSED!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");

        #20;
        $finish;
    end

endmodule