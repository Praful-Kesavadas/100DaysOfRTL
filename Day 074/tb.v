`timescale 1ns / 1ps

module tb_spi_master();

    parameter DATA_WIDTH = 8;
    parameter CLK_DIV    = 4;
    parameter CLK_PERIOD = 20; // 50 MHz

    reg                   clk;
    reg                   nreset;
    reg                   cpol;
    reg                   cpha;
    reg                   start;
    reg  [DATA_WIDTH-1:0] tx_data;
    wire [DATA_WIDTH-1:0] rx_data;
    wire                  busy;
    wire                  done;

    wire                  sclk;
    wire                  mosi;
    reg                   miso;
    wire                  ss_n;

    integer errors = 0;

    // Instantiate SPI Master
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_DIV(CLK_DIV)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .cpol(cpol),
        .cpha(cpha),
        .start(start),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .ss_n(ss_n)
    );

    // 50 MHz clock
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Emulated SPI Slave Device Model
    task spi_slave_emulate(
        input [7:0] slave_tx_data,
        input       exp_cpol,
        input       exp_cpha,
        output [7:0] captured_mosi
    );
        reg [7:0] slave_shift;
        reg [7:0] mosi_shift;
        integer i;
        begin
            slave_shift = slave_tx_data;
            mosi_shift  = 8'h00;

            // Wait for Chip Select assertion
            @(negedge ss_n);

            if (exp_cpha == 1'b0) begin
                // CPHA=0: Drive first MISO bit on SS_N falling edge
                miso = slave_shift[7];
                slave_shift = {slave_shift[6:0], 1'b0};

                for (i = 0; i < 8; i = i + 1) begin
                    // Sample MOSI on Leading Edge
                    if (exp_cpol == 1'b0) @(posedge sclk);
                    else                  @(negedge sclk);
                    mosi_shift = {mosi_shift[6:0], mosi};

                    // Shift MISO on Trailing Edge
                    if (exp_cpol == 1'b0) @(negedge sclk);
                    else                  @(posedge sclk);
                    if (i < 7) begin
                        miso = slave_shift[7];
                        slave_shift = {slave_shift[6:0], 1'b0};
                    end
                end
            end else begin
                // CPHA=1: Drive and Sample
                for (i = 0; i < 8; i = i + 1) begin
                    // Shift MISO on Leading Edge
                    if (exp_cpol == 1'b0) @(posedge sclk);
                    else                  @(negedge sclk);
                    miso = slave_shift[7];
                    slave_shift = {slave_shift[6:0], 1'b0};

                    // Sample MOSI on Trailing Edge
                    if (exp_cpol == 1'b0) @(negedge sclk);
                    else                  @(posedge sclk);
                    mosi_shift = {mosi_shift[6:0], mosi};
                end
            end

            @(posedge ss_n);
            miso = 1'b0;
            captured_mosi = mosi_shift;
        end
    endtask

    // Transaction Verification Task
    task run_spi_test(
        input       test_cpol,
        input       test_cpha,
        input [7:0] master_tx,
        input [7:0] slave_tx
    );
        reg [7:0] slave_received_byte;
        begin
            cpol    = test_cpol;
            cpha    = test_cpha;
            tx_data = master_tx;

            fork
                begin
                    @(negedge clk);
                    start = 1'b1;
                    @(negedge clk);
                    start = 1'b0;
                    @(posedge done);
                end
                begin
                    spi_slave_emulate(slave_tx, test_cpol, test_cpha, slave_received_byte);
                end
            join

            #(CLK_PERIOD * 2);

            // Audit Master and Slave captures
            if (slave_received_byte !== master_tx) begin
                $display("[FAIL] Mode (CPOL=%0b, CPHA=%0b): Slave received 0x%02h, Expected 0x%02h",
                         test_cpol, test_cpha, slave_received_byte, master_tx);
                errors = errors + 1;
            end else if (rx_data !== slave_tx) begin
                $display("[FAIL] Mode (CPOL=%0b, CPHA=%0b): Master received 0x%02h, Expected 0x%02h",
                         test_cpol, test_cpha, rx_data, slave_tx);
                errors = errors + 1;
            end else begin
                $display("[PASS] Mode %0d (CPOL=%0b, CPHA=%0b): TX: 0x%02h | RX: 0x%02h Verified",
                         {test_cpol, test_cpha}, test_cpol, test_cpha, master_tx, rx_data);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_spi_master);

        clk     = 0;
        nreset  = 0;
        cpol    = 0;
        cpha    = 0;
        start   = 0;
        tx_data = 8'h00;
        miso    = 0;

        #(CLK_PERIOD * 5);
        @(negedge clk);
        nreset = 1;
        #(CLK_PERIOD * 5);

        $display("\n=======================================================================================================");
        $display("                   DAY 74: SPI MASTER BUS CONTROLLER (MODES 0, 1, 2, 3) VERIFICATION                   ");
        $display("=======================================================================================================");

        // Test SPI Mode 0 (CPOL=0, CPHA=0)
        $display("\n--- Testing SPI Mode 0 (CPOL=0, CPHA=0) ---");
        run_spi_test(1'b0, 1'b0, 8'hA5, 8'h3C);

        // Test SPI Mode 1 (CPOL=0, CPHA=1)
        $display("\n--- Testing SPI Mode 1 (CPOL=0, CPHA=1) ---");
        run_spi_test(1'b0, 1'b1, 8'h5A, 8'hC3);

        // Test SPI Mode 2 (CPOL=1, CPHA=0)
        $display("\n--- Testing SPI Mode 2 (CPOL=1, CPHA=0) ---");
        run_spi_test(1'b1, 1'b0, 8'hF0, 8'h0F);

        // Test SPI Mode 3 (CPOL=1, CPHA=1)
        $display("\n--- Testing SPI Mode 3 (CPOL=1, CPHA=1) ---");
        run_spi_test(1'b1, 1'b1, 8'h96, 8'h69);

        #(CLK_PERIOD * 20);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 74 SPI MASTER CONTROLLER VERIFICATION SUCCESSFUL");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule