`timescale 1ns / 1ps

module tb_spi_slave();

    parameter DATA_WIDTH = 8;
    parameter CLK_PERIOD = 20;  // 50 MHz System Clock (20 ns)
    parameter SCLK_HALF  = 80;  // 6.25 MHz SCLK (80 ns half-period)

    reg                   clk;
    reg                   nreset;
    reg                   cpol;
    reg                   cpha;
    reg  [DATA_WIDTH-1:0] tx_data;
    wire [DATA_WIDTH-1:0] rx_data;
    wire                  rx_valid;

    reg                   sclk;
    reg                   mosi;
    wire                  miso;
    reg                   ss_n;

    integer errors = 0;

    // Instantiate SPI Slave UUT
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .cpol(cpol),
        .cpha(cpha),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .ss_n(ss_n)
    );

    // 50 MHz Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Synchronous Master Behavioral Driver Task
    task master_transmit_byte(
        input [7:0] master_out,
        input [7:0] slave_preload,
        input       exp_cpol,
        input       exp_cpha
    );
        integer i;
        reg [7:0] captured_miso;
        begin
            cpol    = exp_cpol;
            cpha    = exp_cpha;
            tx_data = slave_preload;
            sclk    = exp_cpol;
            ss_n    = 1'b1;
            mosi    = 1'b0;
            captured_miso = 8'h00;

            #(SCLK_HALF);
            ss_n = 1'b0;
            #(SCLK_HALF); // Lead-in setup delay (allows CDC synchronizer to settle)

            if (exp_cpha == 1'b0) begin
                // -----------------------------------------------------
                // Mode 0 & 2: Sample on Leading Edge, Shift on Trailing
                // -----------------------------------------------------
                mosi = master_out[7]; // Pre-drive MSB before first leading edge

                for (i = 0; i < 8; i = i + 1) begin
                    // 1. Leading Edge: Master samples MISO
                    sclk = ~sclk;
                    #(SCLK_HALF / 2);
                    captured_miso[7 - i] = miso; // Sample at stable center of leading pulse
                    #(SCLK_HALF / 2);

                    // 2. Trailing Edge: Master shifts next MOSI bit
                    sclk = ~sclk;
                    if (i < 7) begin
                        mosi = master_out[6 - i];
                    end
                    #(SCLK_HALF); // Allows slave CDC to detect edge and update MISO
                end
            end else begin
                // -----------------------------------------------------
                // Mode 1 & 3: Shift on Leading Edge, Sample on Trailing
                // -----------------------------------------------------
                for (i = 0; i < 8; i = i + 1) begin
                    // 1. Leading Edge: Master shifts MOSI
                    mosi = master_out[7 - i];
                    sclk = ~sclk;
                    #(SCLK_HALF);

                    // 2. Trailing Edge: Master samples MISO
                    sclk = ~sclk;
                    #(SCLK_HALF / 2);
                    captured_miso[7 - i] = miso; // Sample at stable center of trailing pulse
                    #(SCLK_HALF / 2);
                end
            end

            #(SCLK_HALF);
            ss_n = 1'b1; // Deselect slave
            #(SCLK_HALF);

            // Audit Captures
            if (rx_data !== master_out) begin
                $display("[FAIL] Mode (CPOL=%0b, CPHA=%0b): Slave RX mismatch! Got: 0x%02h, Expected: 0x%02h",
                         exp_cpol, exp_cpha, rx_data, master_out);
                errors = errors + 1;
            end else if (captured_miso !== slave_preload) begin
                $display("[FAIL] Mode (CPOL=%0b, CPHA=%0b): Master captured MISO mismatch! Got: 0x%02h, Expected: 0x%02h",
                         exp_cpol, exp_cpha, captured_miso, slave_preload);
                errors = errors + 1;
            end else begin
                $display("[PASS] Mode %0d (CPOL=%0b, CPHA=%0b): Master TX: 0x%02h | Slave TX: 0x%02h Verified",
                         {exp_cpol, exp_cpha}, exp_cpol, exp_cpha, master_out, slave_preload);
            end

            // Audit Tri-State Output
            if (miso !== 1'bz) begin
                $display("[FAIL] Tri-state violation: MISO not high-Z when SS_N is high!");
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_spi_slave);

        clk     = 0;
        nreset  = 0;
        cpol    = 0;
        cpha    = 0;
        tx_data = 8'h00;
        sclk    = 0;
        mosi    = 0;
        ss_n    = 1;

        // Reset Sequence
        #(CLK_PERIOD * 5);
        @(negedge clk);
        nreset = 1;
        #(CLK_PERIOD * 5);

        $display("\n=======================================================================================================");
        $display("                   DAY 75: SPI SLAVE BUS CONTROLLER (MODES 0, 1, 2, 3) VERIFICATION                    ");
        $display("=======================================================================================================");

        // Test Mode 0 (CPOL=0, CPHA=0)
        $display("\n--- Testing SPI Mode 0 (CPOL=0, CPHA=0) ---");
        master_transmit_byte(8'hA5, 8'h3C, 1'b0, 1'b0);

        // Test Mode 1 (CPOL=0, CPHA=1)
        $display("\n--- Testing SPI Mode 1 (CPOL=0, CPHA=1) ---");
        master_transmit_byte(8'h5A, 8'hC3, 1'b0, 1'b1);

        // Test Mode 2 (CPOL=1, CPHA=0)
        $display("\n--- Testing SPI Mode 2 (CPOL=1, CPHA=0) ---");
        master_transmit_byte(8'hF0, 8'h0F, 1'b1, 1'b0);

        // Test Mode 3 (CPOL=1, CPHA=1)
        $display("\n--- Testing SPI Mode 3 (CPOL=1, CPHA=1) ---");
        master_transmit_byte(8'h96, 8'h69, 1'b1, 1'b1);

        #(CLK_PERIOD * 20);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 75 SPI SLAVE CONTROLLER VERIFICATION SUCCESSFUL");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule