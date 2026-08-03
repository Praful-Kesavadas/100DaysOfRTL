`timescale 1ns / 1ps

module tb_syn_fifo();

    parameter DEPTH               = 16;
    parameter DATA_WIDTH          = 8;
    parameter ALMOST_FULL_THRESH  = 12;
    parameter ALMOST_EMPTY_THRESH = 4;
    parameter ADDR_WIDTH          = $clog2(DEPTH);
    parameter CLK_PERIOD          = 10;

    reg                  clk;
    reg                  nreset;
    reg                  write_en;
    reg                  read_en;
    reg  [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;
    wire                  full;
    wire                  empty;
    wire                  almost_full;
    wire                  almost_empty;

    integer errors = 0;
    integer i;

    // Instantiate UUT
    syn_fifo #(
        .DEPTH(DEPTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ALMOST_FULL_THRESH(ALMOST_FULL_THRESH),
        .ALMOST_EMPTY_THRESH(ALMOST_EMPTY_THRESH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .write_en(write_en),
        .read_en(read_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty),
        .almost_full(almost_full),
        .almost_empty(almost_empty)
    );

    // 100 MHz Clock Generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk      = 0;
        nreset   = 0;
        write_en = 0;
        read_en  = 0;
        data_in  = 0;

        // Apply Reset
        #(CLK_PERIOD * 2);
        nreset = 1;
        #(CLK_PERIOD);

        $display("\n====================================================");
        $display("   DAY 55: SYNCHRONOUS FIFO CORE VERIFICATION");
        $display("====================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Initial Reset State
        // -------------------------------------------------------------
        if (empty && almost_empty && !full && !almost_full) begin
            $display("[PASS] TEST 1: Reset State Verified.");
        end else begin
            $display("[FAIL] TEST 1: Reset State Mismatch!");
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 2: Fill FIFO to DEPTH (16 Entries)
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Burst Write Operations (1 to 16) ---");
        for (i = 1; i <= DEPTH; i = i + 1) begin
            @(negedge clk);
            write_en = 1;
            data_in  = i[7:0];
        end

        @(negedge clk);
        write_en = 0; // Clean strobe deassertion

        @(posedge clk); #1;
        if (full && almost_full) begin
            $display("[PASS] TEST 2: Burst Write Complete! FIFO is FULL.");
        end else begin
            $display("[FAIL] TEST 2: FIFO failed to assert FULL flag!");
            errors = errors + 1;
        end

        // -------------------------------------------------------------
        // TEST 3: Simultaneous Push & Pop on FULL FIFO
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Simultaneous Push/Pop on FULL FIFO ---");
        @(negedge clk);
        write_en = 1; data_in = 8'hFF; // Push 0xFF
        read_en  = 1;                  // Pop 0x01

        @(posedge clk); #1;
        if (full) begin
            $display("[PASS] TEST 3: Push/Pop on FULL maintained capacity.");
        end else begin
            $display("[FAIL] TEST 3: FULL flag lost!");
            errors = errors + 1;
        end

        // FIX: CLEANLY DEASSERT BOTH STROBES BEFORE TEST 4 STARTS
        @(negedge clk);
        write_en = 0;
        read_en  = 0;

        // -------------------------------------------------------------
        // TEST 4: Burst Read & Data Ordering Check
        // Remaining in FIFO: 0x02, 0x03, 0x04, ..., 0x10, 0xFF
        // -------------------------------------------------------------
        $display("\n--- TEST 4: Burst Read Operations & Data Ordering ---");

        for (i = 1; i <= DEPTH; i = i + 1) begin
            @(negedge clk);
            read_en = 1;

            @(posedge clk); #1;
            if (i < DEPTH) begin
                // Expect values 0x02 through 0x10 (i.e., i + 1)
                if (data_out === (i + 1)) begin
                    $display("[PASS] Sample %2d Read, Got: 0x%02h, Expected: 0x%02h", i, data_out, i[ADDR_WIDTH-1:0]+ 1'b1);
                end else begin
                    $display("[FAIL] Read Mismatch at sample %0d! Got 0x%02h, Exp 0x%02h", i, data_out, i + 1);
                    errors = errors + 1;
                end
            end else begin
                // Sample 16 is 0xFF pushed during Test 3
                if (data_out === 8'hFF) begin
                    $display("[PASS] Sample 16 Read: 0x%02h (Pushed during Test 3)", data_out);
                end else begin
                    $display("[FAIL] Read Mismatch at sample 16! Got 0x%02h, Exp 0xFF", data_out);
                    errors = errors + 1;
                end
            end
        end

        @(negedge clk);
        read_en = 0; // Clean strobe deassertion

        @(posedge clk); #1;
        if (empty && almost_empty) begin
            $display("[PASS] TEST 4 Complete! FIFO cleanly returned to EMPTY.");
        end else begin
            $display("[FAIL] TEST 4: FIFO failed to assert EMPTY flag!");
            errors = errors + 1;
        end

        // SUMMARY
        $display("\n====================================================");
        if (errors == 0) $display(" ALL SYNCHRONOUS FIFO TESTS PASSED!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");

        $finish;
    end

endmodule