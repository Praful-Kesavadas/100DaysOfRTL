`timescale 1ns / 1ps

module tb_uart_core();

    parameter CLK_FREQ   = 50_000_000;
    parameter BAUD_RATE  = 115_200;
    parameter CLK_PERIOD = 20; // 50 MHz = 20 ns
    // 1 bit period = 434 * 20 ns = 8680 ns
    parameter BIT_PERIOD = (CLK_FREQ / BAUD_RATE) * CLK_PERIOD;

    reg        clk;
    reg        nreset;
    reg        loopback_en;

    // Host TX
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx_busy;
    wire       tx_done;

    // Host RX
    wire [7:0] rx_data;
    wire       rx_valid;
    wire       rx_busy;
    wire       framing_error;

    // Physical Pins
    wire       tx_serial;
    reg        rx_serial;

    integer errors = 0;

    // Instantiate Full-Duplex Core
    uart_core #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .loopback_en(loopback_en),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_busy(rx_busy),
        .framing_error(framing_error),
        .tx_serial(tx_serial),
        .rx_serial(rx_serial)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    // External Serial Driver Task (Emulates external peer TX)
    task send_external_byte(input [7:0] byte_val);
        integer b;
        begin
            rx_serial = 1'b0; // Start bit
            #(BIT_PERIOD);
            for (b = 0; b < 8; b = b + 1) begin
                rx_serial = byte_val[b]; // Data bits LSB first
                #(BIT_PERIOD);
            end
            rx_serial = 1'b1; // Stop bit
            #(BIT_PERIOD);
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_uart_core);

        clk         = 0;
        nreset      = 0;
        loopback_en = 0;
        tx_start    = 0;
        tx_data     = 8'h00;
        rx_serial   = 1'b1;

        // Reset Sequence
        #(CLK_PERIOD * 5);
        @(negedge clk);
        nreset = 1;
        #(CLK_PERIOD * 5);

        $display("\n=======================================================================================================");
        $display("                   DAY 73: FULL-DUPLEX UART COMMUNICATION CORE VERIFICATION                            ");
        $display("=======================================================================================================");

        // -------------------------------------------------------------
        // TEST 1: Internal Hardware Loopback Mode
        // -------------------------------------------------------------
        $display("\n--- TEST 1: Diagnostic Internal Loopback Mode (0xA5) ---");
        loopback_en = 1'b1;

        fork
            begin
                @(negedge clk);
                tx_data  = 8'hA5;
                tx_start = 1'b1;
                @(negedge clk);
                tx_start = 1'b0;
                @(posedge tx_done);
            end
            begin
                @(posedge rx_valid);
                if (rx_data !== 8'hA5) begin
                    $display("[FAIL] Loopback mismatch! Expected: 0xA5, Got: 0x%02h", rx_data);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] Internal Loopback confirmed: Transmitted 0xA5 -> Received 0xA5");
                end
            end
        join

        #(CLK_PERIOD * 20);

        // -------------------------------------------------------------
        // TEST 2: True Full-Duplex Concurrency (Independent TX and RX)
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Concurrent Full-Duplex Transmission (TX: 0x3C, RX: 0xC3) ---");
        loopback_en = 1'b0; // Connect to external pins

        fork
            // Thread A: Local core transmits 0x3C to external peer
            begin
                @(negedge clk);
                tx_data  = 8'h3C;
                tx_start = 1'b1;
                @(negedge clk);
                tx_start = 1'b0;
                @(posedge tx_done);
                $display("[PASS] Local TX completed transmitting 0x3C");
            end

            // Thread B: External peer simultaneously transmits 0xC3 to local core
            begin
                send_external_byte(8'hC3);
            end

            // Thread C: Local core receives external byte
            begin
                @(posedge rx_valid);
                if (rx_data !== 8'hC3) begin
                    $display("[FAIL] Full-duplex RX mismatch! Expected: 0xC3, Got: 0x%02h", rx_data);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] Full-duplex RX confirmed: Successfully captured 0xC3 concurrently");
                end
            end
        join

        #(CLK_PERIOD * 20);

        // -------------------------------------------------------------
        // TEST 3: Zero-Wait Back-to-Back Burst (Loopback Mode)
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Zero-Wait Back-to-Back Burst Stream (0x11, 0x22, 0x33) ---");
        loopback_en = 1'b1;

        fork
            // Driver Thread: Sends bytes consecutively on tx_done assertion
            begin
                // Byte 1
                @(negedge clk);
                tx_data  = 8'h11;
                tx_start = 1'b1;
                @(negedge clk);
                tx_start = 1'b0;
                @(posedge tx_done);

                // Byte 2 (immediate back-to-back)
                @(negedge clk);
                tx_data  = 8'h22;
                tx_start = 1'b1;
                @(negedge clk);
                tx_start = 1'b0;
                @(posedge tx_done);

                // Byte 3 (immediate back-to-back)
                @(negedge clk);
                tx_data  = 8'h33;
                tx_start = 1'b1;
                @(negedge clk);
                tx_start = 1'b0;
                @(posedge tx_done);
            end

            // Monitor Thread: Verifies all three bytes arrive in sequence
            begin
                // Receive Byte 1
                @(posedge rx_valid);
                if (rx_data !== 8'h11) begin
                    $display("[FAIL] Burst byte 1 mismatch! Expected: 0x11, Got: 0x%02h", rx_data);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] Burst byte 1 verified (0x11)");
                end

                // Receive Byte 2
                @(posedge rx_valid);
                if (rx_data !== 8'h22) begin
                    $display("[FAIL] Burst byte 2 mismatch! Expected: 0x22, Got: 0x%02h", rx_data);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] Burst byte 2 verified (0x22)");
                end

                // Receive Byte 3
                @(posedge rx_valid);
                if (rx_data !== 8'h33) begin
                    $display("[FAIL] Burst byte 3 mismatch! Expected: 0x33, Got: 0x%02h", rx_data);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] Burst byte 3 verified (0x33)");
                end
            end
        join

        // Final Audit
        #(CLK_PERIOD * 20);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 73 FULL-DUPLEX UART CORE VERIFICATION SUCCESSFUL");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule