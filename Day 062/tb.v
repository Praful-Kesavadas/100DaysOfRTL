`timescale 1ns / 1ps

module tb_processor_file_array();

    parameter CLK_PERIOD = 10;
    parameter DATA_WIDTH = 32;
    parameter DEPTH      = 32;
    parameter ADDR_WIDTH = $clog2(DEPTH);

    reg                  clk;
    reg  [ADDR_WIDTH-1:0] rs1_addr_in;
    reg  [ADDR_WIDTH-1:0] rs2_addr_in;
    wire [DATA_WIDTH-1:0] rs1_data_out;
    wire [DATA_WIDTH-1:0] rs2_data_out;

    reg                  write_en;
    reg  [ADDR_WIDTH-1:0] wr_addr;
    reg  [DATA_WIDTH-1:0] wr_data;

    integer errors = 0;

    // Instantiate Register File Core
    processor_file_array #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .rs1_addr_in(rs1_addr_in),
        .rs2_addr_in(rs2_addr_in),
        .rs1_data_out(rs1_data_out),
        .rs2_data_out(rs2_data_out),
        .write_en(write_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data)
    );

    // 100 MHz Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk         = 0;
        rs1_addr_in = 0;
        rs2_addr_in = 0;
        write_en    = 0;
        wr_addr     = 0;
        wr_data     = 0;

        #(CLK_PERIOD * 2);

        $display("\n====================================================");
        $display("   DAY 62: MULTI-PORT REGISTER FILE CORE VERIFICATION");
        $display("====================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Synchronous Write & Concurrent Dual Read (Reg 1 & Reg 2)
        // -------------------------------------------------------------
        $display("--- TEST 1: Synchronous Write & Dual Read ---");
        @(negedge clk);
        write_en = 1; wr_addr = 5'd1; wr_data = 32'hA5A5_1111;
        @(negedge clk);
        write_en = 1; wr_addr = 5'd2; wr_data = 32'h5A5A_2222;
        @(negedge clk);
        write_en = 0;

        // Perform concurrent dual read on rs1 and rs2
        rs1_addr_in = 5'd1;
        rs2_addr_in = 5'd2;
        #1;

        if (rs1_data_out === 32'hA5A5_1111 && rs2_data_out === 32'h5A5A_2222)
            $display("[PASS] Dual Read Match: Reg1 = 0x%08h, Reg2 = 0x%08h", rs1_data_out, rs2_data_out);
        else begin
            $display("[FAIL] Read Mismatch! Reg1 = 0x%08h, Reg2 = 0x%08h", rs1_data_out, rs2_data_out);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 2: Hardwired x0 Zero Register Immutability Check
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Hardwired Register x0 Immutability Guard ---");
        @(negedge clk);
        write_en = 1; wr_addr = 5'd0; wr_data = 32'hDEAD_BEEF; // Attempt overwrite x0
        @(negedge clk);
        write_en = 0;

        rs1_addr_in = 5'd0;
        #1;

        if (rs1_data_out === 32'h0000_0000)
            $display("[PASS] Register x0 correctly held constant 0x00000000!");
        else begin
            $display("[FAIL] Register x0 overwritten! Got 0x%08h", rs1_data_out);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 3: Same-Cycle Write-Through RAW Bypassing
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Same-Cycle Write-Through RAW Bypassing ---");
        @(negedge clk);
        // Simultaneously write to Reg 5 and read from Reg 5 in the SAME cycle
        write_en    = 1; 
        wr_addr     = 5'd5; 
        wr_data     = 32'hCAFE_BABE;
        rs1_addr_in = 5'd5;
        #1; // Read should combinational-forward wr_data BEFORE the clock edge!

        if (rs1_data_out === 32'hCAFE_BABE)
            $display("[PASS] Write-Through Bypass Succeeded! Read 0x%08h instantly before clk edge", rs1_data_out);
        else begin
            $display("[FAIL] Bypass Failed! Expected 0xCAFEBABE, Got 0x%08h", rs1_data_out);
            errors = errors + 1;
        end

        @(negedge clk);
        write_en = 0;

        // SUMMARY
        $display("\n====================================================");
        if (errors == 0) $display(" ALL REGISTER FILE ARRAY TESTS PASSED!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");

        #20;
        $finish;
    end

endmodule