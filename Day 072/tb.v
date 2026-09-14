`timescale 1ns / 1ps

module tb_uart_rx();

    parameter CLK_FREQ        = 50_000_000;
    parameter BAUD_RATE       = 115_200;
    parameter OVERSAMPLE      = 16;
    parameter CLKS_PER_SAMPLE = 27;
    parameter CLK_PERIOD      = 20; // 50 MHz clock = 20 ns
    // Nominal bit time = 432 * 20 ns = 8640 ns
    parameter BIT_PERIOD      = CLKS_PER_SAMPLE * OVERSAMPLE * CLK_PERIOD;

    reg        clk;
    reg        nreset;
    reg        rx_serial;
    wire [7:0] rx_data;
    wire       rx_valid;
    wire       rx_busy;
    wire       framing_error;

    integer errors = 0;

    // Instantiate Unit Under Test
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .OVERSAMPLE(OVERSAMPLE),
        .CLKS_PER_SAMPLE(CLKS_PER_SAMPLE)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .rx_in(rx_serial),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_busy(rx_busy),
        .framing_error(framing_error)
    );

    // 50 MHz System Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Task to transmit a serial byte with configurable bit period and stop bit
    task send_uart_byte(
        input [7:0] byte_to_send,
        input time  custom_bit_period,
        input       stop_bit_val
    );
        integer b;
        begin
            // 1. Start Bit
            rx_serial = 1'b0;
            #(custom_bit_period);

            // 2. 8 Data Bits (LSB First)
            for (b = 0; b < 8; b = b + 1) begin
                rx_serial = byte_to_send[b];
                #(custom_bit_period);
            end

            // 3. Stop Bit
            rx_serial = stop_bit_val;
            #(custom_bit_period);
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_uart_rx);

        clk       = 0;
        nreset    = 0;
        rx_serial = 1;

        // Apply Reset
        #(CLK_PERIOD * 5);
        @(negedge clk);
        nreset = 1;
        #(CLK_PERIOD * 5);

        $display("\n=======================================================================================================");
        $display("                   DAY 72: UART RECEIVER CORE (16x OVERSAMPLING) VERIFICATION                          ");
        $display("=======================================================================================================");

        // -------------------------------------------------------------
        // TEST 1: Standard Byte Reception (0xA5 = 8'b1010_0101)
        // -------------------------------------------------------------
        $display("\n--- TEST 1: Receiving Standard Frame (0xA5) at Nominal Baud ---");
        fork
            begin
                send_uart_byte(8'hA5, BIT_PERIOD, 1'b1);
            end
            begin
                @(posedge rx_valid);
                if (rx_data !== 8'hA5) begin
                    $display("[FAIL] Data mismatch! Expected: 0xA5, Got: 0x%02h", rx_data);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] Received 0x%02h correctly with 0 errors.", rx_data);
                end
            end
        join

        #(CLK_PERIOD * 20);

        // -------------------------------------------------------------
        // TEST 2: Glitch Rejection on Idle Line
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Glitch Filtering on Idle Line ---");
        // Pulse low for only 3 sample ticks (3 * 27 * 20 ns = 1620 ns < 8 sample ticks)
        rx_serial = 1'b0;
        #(CLKS_PER_SAMPLE * 3 * CLK_PERIOD);
        rx_serial = 1'b1;

        #(BIT_PERIOD);
        if (rx_busy !== 1'b0 || rx_valid !== 1'b0) begin
            $display("[FAIL] Receiver falsely locked onto noise glitch!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Transient noise glitch cleanly filtered; Receiver remained IDLE.");
        end

        #(CLK_PERIOD * 20);

        // -------------------------------------------------------------
        // TEST 3: Framing Error Detection (Corrupted Stop Bit)
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Framing Error Detection (Invalid Stop Bit) ---");
        fork
            begin
                // Send byte 0x55 with an illegal Stop Bit (0 instead of 1)
                send_uart_byte(8'h55, BIT_PERIOD, 1'b0);
                rx_serial = 1'b1; // Return line to idle
            end
            begin
                @(posedge framing_error);
                $display("[PASS] Framing error correctly flagged on missing Stop bit.");
            end
        join

        #(CLK_PERIOD * 20);

        // -------------------------------------------------------------
        // TEST 4: Clock Drift Tolerance (+2.5% Slower Remote Transmitter)
        // -------------------------------------------------------------
        $display("\n--- TEST 4: Clock Drift Stress Test (+2.5%% Slower Remote TX) ---");
        fork
            begin
                // Bit period dilated by +2.5%
                send_uart_byte(8'h3C, (BIT_PERIOD * 1025) / 1000, 1'b1);
            end
            begin
                @(posedge rx_valid);
                if (rx_data !== 8'h3C) begin
                    $display("[FAIL] Drift decoding failed! Expected: 0x3C, Got: 0x%02h", rx_data);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] Drift test passed: Byte 0x3C recovered accurately despite +2.5%% period dilation.");
                end
            end
        join

        #(CLK_PERIOD * 20);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 72 UART RECEIVER VERIFICATION SUCCESSFUL");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule