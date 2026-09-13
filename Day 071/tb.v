`timescale 1ns / 1ps

module tb_uart_tx();

    parameter CLK_FREQ     = 50_000_000;
    parameter BAUD_RATE    = 115_200;
    parameter CLKS_PER_BIT = 434;
    parameter CLK_PERIOD   = 20; // 50 MHz = 20 ns period

    reg        clk;
    reg        nreset;
    reg        tx_start;
    reg  [7:0] data_in;
    wire       tx_serial;
    wire       tx_busy;
    wire       tx_done;

    integer errors = 0;

    // Instantiate Unit Under Test
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .tx_start(tx_start),
        .d_in(data_in),
        .tx_serial(tx_serial),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

    // 50 MHz Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Verification Task: Deserializes the serial pin like a UART receiver
    task receive_and_verify(input [7:0] exp_byte);
        reg [7:0] rx_byte;
        integer b;
        begin
            // 1. Wait for Start Bit (falling edge on tx_serial)
            @(negedge tx_serial);

            // 2. Sample at midpoint of Start Bit (0.5 baud period)
            #( (CLKS_PER_BIT * CLK_PERIOD) / 2 );
            if (tx_serial !== 1'b0) begin
                $display("[FAIL] Start bit was not LOW! Got: %b", tx_serial);
                errors = errors + 1;
            end

            // 3. Sample 8 Data Bits at their respective centers
            for (b = 0; b < 8; b = b + 1) begin
                #(CLKS_PER_BIT * CLK_PERIOD);
                rx_byte[b] = tx_serial;
            end

            // 4. Sample Stop Bit (should be HIGH)
            #(CLKS_PER_BIT * CLK_PERIOD);
            if (tx_serial !== 1'b1) begin
                $display("[FAIL] Stop bit was not HIGH! Got: %b", tx_serial);
                errors = errors + 1;
            end

            // 5. Compare Deserialized Payload
            if (rx_byte !== exp_byte) begin
                $display("[FAIL] Data Mismatch! Expected: 0x%02h ('%c') | Received: 0x%02h ('%c')",
                         exp_byte, exp_byte, rx_byte, rx_byte);
                errors = errors + 1;
            end else begin
                $display("[PASS] Received Byte: 0x%02h ('%c') Frame Validated", rx_byte, rx_byte);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_uart_tx);

        clk      = 0;
        nreset   = 0;
        tx_start = 0;
        data_in  = 8'h00;

        // Apply Reset
        #(CLK_PERIOD * 5);
        @(negedge clk);
        nreset = 1;
        #(CLK_PERIOD * 2);

        $display("\n=======================================================================================================");
        $display("                         DAY 71: UART TRANSMITTER CORE VERIFICATION                                    ");
        $display("=======================================================================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Check Idle Condition
        // -------------------------------------------------------------
        if (tx_serial !== 1'b1 || tx_busy !== 1'b0) begin
            $display("[FAIL] TX Line not idle! tx_serial=%b, tx_busy=%b", tx_serial, tx_busy);
            errors = errors + 1;
        end else begin
            $display("[PASS] Idle state verified: tx_serial = HIGH (MARK), tx_busy = 0");
        end

        // -------------------------------------------------------------
        // TEST 2: Transmit First Byte (0x55 = 8'b0101_0101)
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Transmitting 0x55 (Alternating Bits Pattern) ---");
        fork
            begin
                @(negedge clk);
                data_in  = 8'h55;
                tx_start = 1'b1;
                @(negedge clk);
                tx_start = 1'b0;
            end
            begin
                receive_and_verify(8'h55);
            end
        join
        @(posedge tx_done);

        // -------------------------------------------------------------
        // TEST 3: Transmit Second Byte (0xA7 = 8'b1010_0111)
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Transmitting 0xA7 ---");
        #(CLK_PERIOD * 10);
        fork
            begin
                @(negedge clk);
                data_in  = 8'hA7;
                tx_start = 1'b1;
                @(negedge clk);
                tx_start = 1'b0;
            end
            begin
                receive_and_verify(8'hA7);
            end
        join
        @(posedge tx_done);

        // -------------------------------------------------------------
        // TEST 4: Re-trigger Immunity (Assert tx_start mid-transmission)
        // -------------------------------------------------------------
        $display("\n--- TEST 4: Verifying Mid-Transmission Retrigger Immunity ---");
        #(CLK_PERIOD * 10);
        fork
            begin
                @(negedge clk);
                data_in  = 8'h3C; // Target payload
                tx_start = 1'b1;
                @(negedge clk);
                tx_start = 1'b0;

                // Attempt to corrupt mid-flight during the DATA state
                #(CLKS_PER_BIT * CLK_PERIOD * 3);
                @(negedge clk);
                data_in  = 8'hFF;
                tx_start = 1'b1;
                @(negedge clk);
                tx_start = 1'b0;
            end
            begin
                receive_and_verify(8'h3C);
            end
        join
        @(posedge tx_done);

        // Final Audit
        #(CLK_PERIOD * 20);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 71 UART TRANSMITTER VERIFICATION SUCCESSFUL: 0 ERRORS DETECTED! (PASSED)");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule