`timescale 1ns / 1ps

module tb_i2c_slave_eeprom();

    parameter CLK_PERIOD   = 20;  // 50 MHz System Clock (20 ns)
    parameter SCL_HALF     = 500; // Fast behavioral SCL half-period (1 MHz equivalent for simulation)
    parameter [6:0] SLAVE_ADDR = 7'h50;

    reg clk;
    reg nreset;

    reg master_scl_driver;
    reg master_sda_driver;

    wire scl;
    wire sda;

    // Open-Drain Pull-Up Resistors
    pullup(scl);
    pullup(sda);

    assign scl = (master_scl_driver == 1'b0) ? 1'b0 : 1'bz;
    assign sda = (master_sda_driver == 1'b0) ? 1'b0 : 1'bz;

    integer errors = 0;

    // Instantiate UUT
    i2c_slave_eeprom #(
        .SLAVE_ADDR(SLAVE_ADDR),
        .MEM_DEPTH(256)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .scl(scl),
        .sda(sda)
    );

    // 50 MHz Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // -----------------------------------------------------------------
    // Master Bus Emulation Driver Tasks
    // -----------------------------------------------------------------
    task i2c_start();
        begin
            master_sda_driver = 1'b1;
            master_scl_driver = 1'b1;
            #(SCL_HALF);
            master_sda_driver = 1'b0; // Falling SDA while SCL is HIGH
            #(SCL_HALF);
            master_scl_driver = 1'b0;
            #(SCL_HALF);
        end
    endtask

    task i2c_stop();
        begin
            master_sda_driver = 1'b0;
            master_scl_driver = 1'b0;
            #(SCL_HALF);
            master_scl_driver = 1'b1;
            #(SCL_HALF);
            master_sda_driver = 1'b1; // Rising SDA while SCL is HIGH
            #(SCL_HALF);
        end
    endtask

    task i2c_write_byte(
        input  [7:0] byte_in,
        output       ack_out
    );
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                master_sda_driver = byte_in[i];
                #(SCL_HALF);
                master_scl_driver = 1'b1;
                #(SCL_HALF);
                master_scl_driver = 1'b0;
            end

            // 9th Cycle: Release SDA to sample Slave ACK
            master_sda_driver = 1'b1;
            #(SCL_HALF);
            master_scl_driver = 1'b1;
            #(SCL_HALF / 2);
            ack_out = sda; // Sample ACK (0 = ACK, 1 = NACK)
            #(SCL_HALF / 2);
            master_scl_driver = 1'b0;
            #(SCL_HALF);
        end
    endtask

    task i2c_read_byte(
        input        master_ack_level, // 0 = ACK (continue), 1 = NACK (stop)
        output [7:0] byte_out
    );
        integer i;
        begin
            master_sda_driver = 1'b1; // Release SDA for Slave driving

            for (i = 7; i >= 0; i = i - 1) begin
                #(SCL_HALF);
                master_scl_driver = 1'b1;
                #(SCL_HALF / 2);
                byte_out[i] = sda;
                #(SCL_HALF / 2);
                master_scl_driver = 1'b0;
            end

            // 9th Cycle: Drive Master ACK/NACK
            master_sda_driver = master_ack_level;
            #(SCL_HALF);
            master_scl_driver = 1'b1;
            #(SCL_HALF);
            master_scl_driver = 1'b0;
            master_sda_driver = 1'b1; // Release
            #(SCL_HALF);
        end
    endtask

    // -----------------------------------------------------------------
    // Verification Test Program
    // -----------------------------------------------------------------
    reg       ack_bit;
    reg [7:0] read_val;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_i2c_slave_eeprom);

        clk               = 0;
        nreset            = 0;
        master_scl_driver = 1;
        master_sda_driver = 1;

        #(CLK_PERIOD * 5);
        @(negedge clk);
        nreset = 1;
        #(CLK_PERIOD * 5);

        $display("\n=======================================================================================================");
        $display("                   DAY 77: I2C SLAVE EEPROM SIMULATION CORE VERIFICATION                               ");
        $display("=======================================================================================================");

        // --- TEST 1: Byte Write Operation ---
        $display("\n--- TEST 1: Byte Write (Write 0xA5 to Memory Address 0x10) ---");
        i2c_start();
        i2c_write_byte({SLAVE_ADDR, 1'b0}, ack_bit); // Device Addr + Write (0xA0)
        if (ack_bit !== 1'b0) begin $display("[FAIL] Device Address NACKed!"); errors = errors + 1; end

        i2c_write_byte(8'h10, ack_bit); // Word Address 0x10
        if (ack_bit !== 1'b0) begin $display("[FAIL] Word Address NACKed!"); errors = errors + 1; end

        i2c_write_byte(8'hA5, ack_bit); // Payload Data 0xA5
        if (ack_bit !== 1'b0) begin $display("[FAIL] Data Byte NACKed!"); errors = errors + 1; end
        i2c_stop();

        #(SCL_HALF * 2);

        // --- TEST 2: Random Read Operation ---
        $display("\n--- TEST 2: Random Read (Read from Address 0x10, Expect 0xA5) ---");
        i2c_start();
        i2c_write_byte({SLAVE_ADDR, 1'b0}, ack_bit); // Dummy Write to set address pointer
        i2c_write_byte(8'h10, ack_bit);

        i2c_start(); // Repeated START
        i2c_write_byte({SLAVE_ADDR, 1'b1}, ack_bit); // Device Addr + Read (0xA1)
        if (ack_bit !== 1'b0) begin $display("[FAIL] Repeated START Read Address NACKed!"); errors = errors + 1; end

        i2c_read_byte(1'b1, read_val); // Read byte with Master NACK
        i2c_stop();

        if (read_val === 8'hA5)
            $display("[PASS] Random Read Verified: Read 0x%02h from Addr 0x10", read_val);
        else begin
            $display("[FAIL] Random Read mismatch! Got: 0x%02h, Expected: 0xA5", read_val);
            errors = errors + 1;
        end

        // --- TEST 3: Sequential / Page Write ---
        $display("\n--- TEST 3: Sequential Page Write (3 Bytes starting at Addr 0x20) ---");
        i2c_start();
        i2c_write_byte({SLAVE_ADDR, 1'b0}, ack_bit);
        i2c_write_byte(8'h20, ack_bit); // Starting Address 0x20
        i2c_write_byte(8'h11, ack_bit); // Addr 0x20
        i2c_write_byte(8'h22, ack_bit); // Addr 0x21
        i2c_write_byte(8'h33, ack_bit); // Addr 0x22
        i2c_stop();

        #(SCL_HALF * 2);

        // --- TEST 4: Sequential Read ---
        $display("\n--- TEST 4: Sequential Read (Read 3 Bytes starting at Addr 0x20) ---");
        i2c_start();
        i2c_write_byte({SLAVE_ADDR, 1'b0}, ack_bit);
        i2c_write_byte(8'h20, ack_bit); // Set pointer to 0x20

        i2c_start(); // Repeated START
        i2c_write_byte({SLAVE_ADDR, 1'b1}, ack_bit);

        i2c_read_byte(1'b0, read_val); // Master ACK -> Expect 0x11
        if (read_val !== 8'h11) begin $display("[FAIL] Seq Byte 0 mismatch! Got 0x%02h", read_val); errors = errors + 1; end

        i2c_read_byte(1'b0, read_val); // Master ACK -> Expect 0x22
        if (read_val !== 8'h22) begin $display("[FAIL] Seq Byte 1 mismatch! Got 0x%02h", read_val); errors = errors + 1; end

        i2c_read_byte(1'b1, read_val); // Master NACK -> Expect 0x33
        if (read_val !== 8'h33) begin $display("[FAIL] Seq Byte 2 mismatch! Got 0x%02h", read_val); errors = errors + 1; end
        i2c_stop();

        if (errors == 0)
            $display("[PASS] Sequential Read Sequence Verified (0x11, 0x22, 0x33)");

        // --- TEST 5: Address Mismatch Rejection ---
        $display("\n--- TEST 5: Device Address Mismatch Rejection ---");
        i2c_start();
        i2c_write_byte({7'h5A, 1'b0}, ack_bit); // Unmatched address 0x5A
        i2c_stop();

        if (ack_bit === 1'b1)
            $display("[PASS] Slave correctly NACKed unmatched device address (0x5A)");
        else begin
            $display("[FAIL] Slave erroneously ACKed unmatched device address!");
            errors = errors + 1;
        end

        #(CLK_PERIOD * 20);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 77 I2C SLAVE EEPROM VERIFICATION SUCCESSFUL");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule