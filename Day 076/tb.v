`timescale 1ns / 1ps

module tb_i2c_master();

    parameter CLK_PERIOD   = 20;         // 50 MHz System Clock (20 ns)
    parameter SYS_CLK_FREQ = 50_000_000;
    parameter I2C_BUS_FREQ = 1_000_000;  // 1 MHz Fast-Mode for accelerated simulation

    reg        clk;
    reg        nreset;

    reg        cmd_start;
    reg        cmd_stop;
    reg        cmd_read;
    reg        cmd_write;
    reg  [7:0] tx_data;
    reg        ack_in;

    wire [7:0] rx_data;
    wire       rx_ack;
    wire       busy;
    wire       done;

    wire       scl;
    wire       sda;

    // Physical Open-Drain Pull-Up Resistors
    pullup(scl);
    pullup(sda);

    integer errors = 0;

    // Instantiate I2C Master UUT
    i2c_master #(
        .SYS_CLK_FREQ(SYS_CLK_FREQ),
        .I2C_BUS_FREQ(I2C_BUS_FREQ)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .cmd_start(cmd_start),
        .cmd_stop(cmd_stop),
        .cmd_read(cmd_read),
        .cmd_write(cmd_write),
        .tx_data(tx_data),
        .ack_in(ack_in),
        .rx_data(rx_data),
        .rx_ack(rx_ack),
        .busy(busy),
        .done(done),
        .scl(scl),
        .sda(sda)
    );

    // 50 MHz System Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // -----------------------------------------------------------------
    // Behavioral Emulated I2C Slave Model
    // -----------------------------------------------------------------
    reg slave_sda_driver;
    reg slave_scl_driver;
    reg slave_stretch_en;

    assign sda = (slave_sda_driver == 1'b0) ? 1'b0 : 1'bz;
    assign scl = (slave_scl_driver == 1'b0) ? 1'b0 : 1'bz;

    reg [7:0] slave_received_byte;
    reg [7:0] slave_send_byte;

    task slave_listen_and_ack(input [7:0] expected_data);
        integer i;
        begin
            slave_sda_driver = 1'b1; // Release SDA
            for (i = 7; i >= 0; i = i - 1) begin
                @(posedge scl);
                slave_received_byte[i] = sda;
                @(negedge scl);
            end

            // Verify Data
            if (slave_received_byte !== expected_data) begin
                $display("[FAIL] Slave received 0x%02h, Expected: 0x%02h", slave_received_byte, expected_data);
                errors = errors + 1;
            end else begin
                $display("[PASS] Slave successfully received byte: 0x%02h", slave_received_byte);
            end

            // Drive ACK (0) on 9th SCL cycle
            slave_sda_driver = 1'b0;
            @(negedge scl);
            slave_sda_driver = 1'b1; // Release
        end
    endtask

    task slave_transmit_and_receive_ack(input [7:0] byte_to_send);
        integer i;
        begin
            slave_send_byte = byte_to_send;
            for (i = 7; i >= 0; i = i - 1) begin
                slave_sda_driver = slave_send_byte[i];
                @(posedge scl);
                @(negedge scl);
            end

            // Release SDA for Master ACK
            slave_sda_driver = 1'b1;
            @(posedge scl);
            $display("[INFO] Slave sampled Master ACK/NACK: %0b", sda);
            @(negedge scl);
        end
    endtask

    // -----------------------------------------------------------------
    // Slave Listener with Mid-Byte Clock Stretch Injection
    // -----------------------------------------------------------------
    task slave_listen_with_stretch(input [7:0] expected_data);
        integer i;
        begin
            slave_sda_driver = 1'b1; // Release SDA

            for (i = 7; i >= 0; i = i - 1) begin
                @(posedge scl);
                slave_received_byte[i] = sda;
                @(negedge scl);

                // Inject clock stretch right after Bit 4
                if (i == 4) begin
                    slave_scl_driver = 1'b0; // Clamp SCL low
                    $display("[INFO] Slave asserted clock stretch (SCL held low)");
                    #(CLK_PERIOD * 40);      // Hold low for 40 system clock cycles
                    slave_scl_driver = 1'b1; // Release SCL
                    $display("[INFO] Slave released clock stretch");
                end
            end

            // Verify Data
            if (slave_received_byte !== expected_data) begin
                $display("[FAIL] Slave received 0x%02h, Expected: 0x%02h", slave_received_byte, expected_data);
                errors = errors + 1;
            end else begin
                $display("[PASS] Slave successfully received byte with stretch: 0x%02h", slave_received_byte);
            end

            // Drive ACK on 9th SCL cycle
            slave_sda_driver = 1'b0;
            @(negedge scl);
            slave_sda_driver = 1'b1;
        end
    endtask

    // -----------------------------------------------------------------
    // Master Host Test Program
    // -----------------------------------------------------------------
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_i2c_master);

        clk              = 0;
        nreset           = 0;
        cmd_start        = 0;
        cmd_stop         = 0;
        cmd_read         = 0;
        cmd_write        = 0;
        tx_data          = 8'h00;
        ack_in           = 0;
        slave_sda_driver = 1;
        slave_scl_driver = 1;
        slave_stretch_en = 0;

        #(CLK_PERIOD * 5);
        @(negedge clk);
        nreset = 1;
        #(CLK_PERIOD * 5);

        $display("\n=======================================================================================================");
        $display("                   DAY 76: I2C MASTER PROTOCOL ENGINE VERIFICATION SUITE                                ");
        $display("=======================================================================================================");

        // --- TEST 1: START + Write Slave Device Address (0x50 << 1 | 0 = 0xA0) ---
        $display("\n--- TEST 1: Generate START Condition and Write Device Address (0xA0) ---");
        @(negedge clk);
        cmd_start = 1;
        @(negedge clk);
        cmd_start = 0;
        @(posedge done);

        fork
            begin
                @(negedge clk);
                cmd_write = 1;
                tx_data   = 8'hA0;
                @(negedge clk);
                cmd_write = 0;
                @(posedge done);
            end
            begin
                slave_listen_and_ack(8'hA0);
            end
        join

        if (rx_ack == 1'b0)
            $display("[PASS] Master successfully captured Slave ACK for Address 0xA0");
        else begin
            $display("[FAIL] Master captured NACK for Address 0xA0!");
            errors = errors + 1;
        end

        // --- TEST 2: Write Internal Register Data (0x3C) ---
        $display("\n--- TEST 2: Write Payload Data Byte (0x3C) ---");
        fork
            begin
                @(negedge clk);
                cmd_write = 1;
                tx_data   = 8'h3C;
                @(negedge clk);
                cmd_write = 0;
                @(posedge done);
            end
            begin
                slave_listen_and_ack(8'h3C);
            end
        join

        // --- TEST 3: Repeated START + Read Mode (0x50 << 1 | 1 = 0xA1) ---
        $display("\n--- TEST 3: Repeated START + Read Device Address (0xA1) ---");
        @(negedge clk);
        cmd_start = 1; // Repeated START
        @(negedge clk);
        cmd_start = 0;
        @(posedge done);

        fork
            begin
                @(negedge clk);
                cmd_write = 1;
                tx_data   = 8'hA1;
                @(negedge clk);
                cmd_write = 0;
                @(posedge done);
            end
            begin
                slave_listen_and_ack(8'hA1);
            end
        join

        // --- TEST 4: Read Byte from Slave (Slave transmits 0xE7, Master returns NACK) ---
        $display("\n--- TEST 4: Read Byte (0xE7) with Master NACK ---");
        fork
            begin
                @(negedge clk);
                cmd_read = 1;
                ack_in   = 1'b1; // Send NACK at end of read
                @(negedge clk);
                cmd_read = 0;
                @(posedge done);
            end
            begin
                slave_transmit_and_receive_ack(8'hE7);
            end
        join

        if (rx_data === 8'hE7)
            $display("[PASS] Master successfully captured Read Data: 0x%02h", rx_data);
        else begin
            $display("[FAIL] Master Read mismatch! Got: 0x%02h, Expected: 0xE7", rx_data);
            errors = errors + 1;
        end

        // --- TEST 5: Clock Stretching Verification ---
        $display("\n--- TEST 5: Clock Stretching Recovery Test ---");
        fork
            begin
                @(negedge clk);
                cmd_write = 1;
                tx_data   = 8'h55;
                @(negedge clk);
                cmd_write = 0;
                @(posedge done);
            end
            begin
                slave_listen_with_stretch(8'h55);
            end
        join

        // --- TEST 6: STOP Condition ---
        $display("\n--- TEST 6: Generate STOP Condition ---");
        @(negedge clk);
        cmd_stop = 1;
        @(negedge clk);
        cmd_stop = 0;
        @(posedge done);

        #(CLK_PERIOD * 20);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 76 I2C MASTER VERIFICATION SUCCESSFUL: 0 ERRORS DETECTED! (PASSED)");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule