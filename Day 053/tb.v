`timescale 1ns / 1ps

module tb_true_dual_port_sram();

    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 16;
    parameter ADDR_WIDTH = $clog2(DEPTH);
    parameter CLK_PERIOD = 10;

    reg                  clk;

    // Port A
    reg                  write_en_a;
    reg  [ADDR_WIDTH-1:0] addr_a;
    reg  [DATA_WIDTH-1:0] data_in_a;
    wire [DATA_WIDTH-1:0] data_out_a;

    // Port B
    reg                  write_en_b;
    reg  [ADDR_WIDTH-1:0] addr_b;
    reg  [DATA_WIDTH-1:0] data_in_b;
    wire [DATA_WIDTH-1:0] data_out_b;

    integer errors = 0;

    // Instantiate UUT
    true_dual_port_sram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .write_en_a(write_en_a),
        .addr_a(addr_a),
        .data_in_a(data_in_a),
        .data_out_a(data_out_a),
        .write_en_b(write_en_b),
        .addr_b(addr_b),
        .data_in_b(data_in_b),
        .data_out_b(data_out_b)
    );

    // 100 MHz Clock Generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk        = 0;
        write_en_a = 0; addr_a = 0; data_in_a = 0;
        write_en_b = 0; addr_b = 0; data_in_b = 0;

        #(CLK_PERIOD * 2);

        $display("\n====================================================");
        $display("   DAY 53: TRUE DUAL-PORT SRAM VERIFICATION");
        $display("====================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Dual Write (Simultaneous writes to Addr 2 and Addr 5)
        // -------------------------------------------------------------
        $display("--- TEST 1: Dual Write (Port A -> Addr 2, Port B -> Addr 5) ---");
        @(negedge clk);
        write_en_a = 1; addr_a = 4'h2; data_in_a = 8'hAA;
        write_en_b = 1; addr_b = 4'h5; data_in_b = 8'hBB;

        @(posedge clk); #1;
        $display("[INFO] Wrote 8'hAA to Addr 2 via Port A, 8'hBB to Addr 5 via Port B");

        // -------------------------------------------------------------
        // TEST 2: Dual Read (Simultaneous reads from Addr 2 and Addr 5)
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Dual Read (Port A Reads Addr 5, Port B Reads Addr 2) ---");
        @(negedge clk);
        write_en_a = 0; addr_a = 4'h5; // Port A reads Addr 5
        write_en_b = 0; addr_b = 4'h2; // Port B reads Addr 2

        @(posedge clk); #1;
        if (data_out_a === 8'hBB && data_out_b === 8'hAA) begin
            $display("[PASS] Dual Read Success! Port A(Addr 5) = 8'h%h, Port B(Addr 2) = 8'h%h", data_out_a, data_out_b);
        end else begin
            $display("[FAIL] Dual Read Mismatch! Port A = 8'h%h (Exp 8'hBB), Port B = 8'h%h (Exp 8'hAA)", data_out_a, data_out_b);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 3: Split Operation (Port A Writes Addr 9, Port B Reads Addr 2)
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Split Read/Write ---");
        @(negedge clk);
        write_en_a = 1; addr_a = 4'h9; data_in_a = 8'hCC; // Port A Write
        write_en_b = 0; addr_b = 4'h2;                     // Port B Read

        @(posedge clk); #1;
        if (data_out_b === 8'hAA) begin
            $display("[PASS] Split Success! Port B read Addr 2 = 8'h%h while Port A wrote Addr 9.", data_out_b);
        end else begin
            $display("[FAIL] Split Read Failed! Got 8'h%h", data_out_b);
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 4: Cross-Port Read/Write Collision (Port A Writes Addr 9, Port B Reads Addr 9)
        // Expected: READ_FIRST behavior on Port B (data_out_b gets old value 8'hCC)
        // -------------------------------------------------------------
        $display("\n--- TEST 4: Cross-Port Collision Check (Same Address 9) ---");
        @(negedge clk);
        write_en_a = 1; addr_a = 4'h9; data_in_a = 8'hDD; // Port A overwrites Addr 9
        write_en_b = 0; addr_b = 4'h9;                     // Port B reads Addr 9 simultaneously

        @(posedge clk); #1;
        if (data_out_b === 8'hCC) begin
            $display("[PASS] Collision Verified! Port B output retained old value (8'hCC) during Port A write.");
        end else begin
            $display("[FAIL] Collision Mismatch! Got 8'h%h", data_out_b);
            errors = errors + 1;
        end

        // Verify updated value on next cycle
        @(negedge clk);
        write_en_a = 0; addr_a = 4'h9;

        @(posedge clk); #1;
        if (data_out_a === 8'hDD) begin
            $display("[PASS] Memory correctly updated post-collision: Addr 9 = 8'h%h", data_out_a);
        end else begin
            $display("[FAIL] Memory update check failed! Got 8'h%h", data_out_a);
            errors = errors + 1;
        end

        // SUMMARY
        $display("\n====================================================");
        if (errors == 0) $display(" ALL TRUE DUAL-PORT SRAM TESTS PASSED!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");

        $finish;
    end

endmodule