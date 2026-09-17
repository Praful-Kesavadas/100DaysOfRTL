`timescale 1ns / 1ps

module tb_spi_core();

    parameter DATA_WIDTH = 8;
    parameter CLK_DIV    = 8;
    parameter CLK_PERIOD = 20; // 50 MHz = 20 ns

    reg                   clk;
    reg                   nreset;
    reg                   loopback_en;
    reg                   cpol;
    reg                   cpha;

    // Master Interface
    reg                   m_start;
    reg  [DATA_WIDTH-1:0] m_tx_data;
    wire [DATA_WIDTH-1:0] m_rx_data;
    wire                  m_busy;
    wire                  m_done;

    // Slave Interface
    reg  [DATA_WIDTH-1:0] s_tx_data;
    wire [DATA_WIDTH-1:0] s_rx_data;
    wire                  s_rx_valid;

    // External Bus Pins
    wire                  sclk_out;
    wire                  mosi_out;
    wire                  ss_n_out;
    reg                   miso_in;

    reg                   sclk_in;
    reg                   mosi_in;
    reg                   ss_n_in;
    wire                  miso_out;

    integer errors = 0;

    // Instantiate SPI Core UUT
    spi_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_DIV(CLK_DIV)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .loopback_en(loopback_en),
        .cpol(cpol),
        .cpha(cpha),
        .m_start(m_start),
        .m_tx_data(m_tx_data),
        .m_rx_data(m_rx_data),
        .m_busy(m_busy),
        .m_done(m_done),
        .s_tx_data(s_tx_data),
        .s_rx_data(s_rx_data),
        .s_rx_valid(s_rx_valid),
        .sclk_out(sclk_out),
        .mosi_out(mosi_out),
        .ss_n_out(ss_n_out),
        .miso_in(miso_in),
        .sclk_in(sclk_in),
        .mosi_in(mosi_in),
        .ss_n_in(ss_n_in),
        .miso_out(miso_out)
    );

    // 50 MHz System Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Diagnostic Loopback Transfer Task
    task run_loopback_test(
        input       test_cpol,
        input       test_cpha,
        input [7:0] master_byte,
        input [7:0] slave_byte
    );
        begin
            cpol        = test_cpol;
            cpha        = test_cpha;
            m_tx_data   = master_byte;
            s_tx_data   = slave_byte;
            loopback_en = 1'b1;

            @(negedge clk);
            m_start = 1'b1;
            @(negedge clk);
            m_start = 1'b0;

            // Wait for Master transaction completion
            @(posedge m_done);
            #(CLK_PERIOD * 4); // Settle status registers

            if (m_rx_data !== slave_byte) begin
                $display("[FAIL] Mode (CPOL=%0b, CPHA=%0b): Master RX mismatch! Got: 0x%02h, Expected: 0x%02h",
                         test_cpol, test_cpha, m_rx_data, slave_byte);
                errors = errors + 1;
            end else if (s_rx_data !== master_byte) begin
                $display("[FAIL] Mode (CPOL=%0b, CPHA=%0b): Slave RX mismatch! Got: 0x%02h, Expected: 0x%02h",
                         test_cpol, test_cpha, s_rx_data, master_byte);
                errors = errors + 1;
            end else begin
                $display("[PASS] Mode %0d (CPOL=%0b, CPHA=%0b) Loopback Verified: Master TX: 0x%02h | Slave TX: 0x%02h",
                         {test_cpol, test_cpha}, test_cpol, test_cpha, master_byte, slave_byte);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_spi_core);

        clk         = 0;
        nreset      = 0;
        loopback_en = 0;
        cpol        = 0;
        cpha        = 0;
        m_start     = 0;
        m_tx_data   = 8'h00;
        s_tx_data   = 8'h00;
        miso_in     = 1'b0;
        sclk_in     = 1'b0;
        mosi_in     = 1'b0;
        ss_n_in     = 1'b1;

        // Reset Sequence
        #(CLK_PERIOD * 5);
        @(negedge clk);
        nreset = 1;
        #(CLK_PERIOD * 5);

        $display("\n=======================================================================================================");
        $display("                   BONUS: SPI COMMUNICATION CORE (MASTER + SLAVE) VERIFICATION                         ");
        $display("=======================================================================================================");

        // Test Internal Diagnostic Loopback across all 4 modes
        $display("\n--- TEST 1: Internal Loopback Mode 0 (CPOL=0, CPHA=0) ---");
        run_loopback_test(1'b0, 1'b0, 8'hA5, 8'h3C);

        $display("\n--- TEST 2: Internal Loopback Mode 1 (CPOL=0, CPHA=1) ---");
        run_loopback_test(1'b0, 1'b1, 8'h5A, 8'hC3);

        $display("\n--- TEST 3: Internal Loopback Mode 2 (CPOL=1, CPHA=0) ---");
        run_loopback_test(1'b1, 1'b0, 8'hF0, 8'h0F);

        $display("\n--- TEST 4: Internal Loopback Mode 3 (CPOL=1, CPHA=1) ---");
        run_loopback_test(1'b1, 1'b1, 8'h96, 8'h69);

        // Test Burst Streaming across loopback
        $display("\n--- TEST 5: Back-to-Back Burst Transfers (Mode 0) ---");
        run_loopback_test(1'b0, 1'b0, 8'h11, 8'hEE);
        run_loopback_test(1'b0, 1'b0, 8'h22, 8'hDD);
        run_loopback_test(1'b0, 1'b0, 8'h33, 8'hCC);

        #(CLK_PERIOD * 20);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   SPI CORE VERIFICATION SUCCESSFUL");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule