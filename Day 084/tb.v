`timescale 1ns / 1ps

module tb_riscv_wb_stage();

    parameter CLK_PERIOD = 10;

    reg         clk;
    reg  [31:0] mem_wb_wdata;
    reg  [4:0]  mem_wb_rd;
    reg  [6:0]  mem_wb_opcode;
    reg         mem_wb_reg_write;

    // WB Stage Outputs
    wire [31:0] wb_rf_wdata;
    wire [4:0]  wb_rf_rd;
    wire        wb_rf_reg_write;
    wire [31:0] wb_fwd_data;
    wire        wb_retired_valid;
    wire [4:0]  wb_retired_rd;
    wire [31:0] wb_retired_data;

    // RegFile Ports
    reg  [4:0]  rf_raddr1;
    reg  [4:0]  rf_raddr2;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;

    integer errors = 0;

    // Instantiate WB Stage
    riscv_wb_stage u_wb_stage (
        .mem_wb_wdata    (mem_wb_wdata),
        .mem_wb_rd       (mem_wb_rd),
        .mem_wb_opcode   (mem_wb_opcode),
        .mem_wb_reg_write(mem_wb_reg_write),
        .wb_rf_wdata     (wb_rf_wdata),
        .wb_rf_rd        (wb_rf_rd),
        .wb_rf_reg_write (wb_rf_reg_write),
        .wb_fwd_data     (wb_fwd_data),
        .wb_retired_valid(wb_retired_valid),
        .wb_retired_rd   (wb_retired_rd),
        .wb_retired_data (wb_retired_data)
    );

    // Instantiate Register File (Closing the loop)
    riscv_regfile u_regfile (
        .clk   (clk),
        .reg_write   (wb_rf_reg_write),
        .rd (wb_rf_rd),
        .w_data (wb_rf_wdata),
        .rs1(rf_raddr1),
        .rdata1(rf_rdata1),
        .rs2(rf_raddr2),
        .rdata2(rf_rdata2)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_riscv_wb_stage);

        clk              = 0;
        mem_wb_wdata     = 32'd0;
        mem_wb_rd        = 5'd0;
        mem_wb_opcode    = 7'b0000000; // Hardware Bubble
        mem_wb_reg_write = 1'b0;
        rf_raddr1        = 5'd0;
        rf_raddr2        = 5'd0;

        #(CLK_PERIOD * 2);

        $display("\n=======================================================================================================");
        $display("                   DAY 84: RISC-V WRITEBACK (WB) & REGFILE LOOP CLOSURE VERIFICATION                   ");
        $display("=======================================================================================================");

        // --- TEST 1: Standard Register Writeback ---
        $display("\n--- TEST 1: Standard Writeback to Register x5 ---");
        @(negedge clk);
        mem_wb_wdata     = 32'hA5A5_5A5A;
        mem_wb_rd        = 5'd5;
        mem_wb_opcode    = 7'b0110011; // R-type
        mem_wb_reg_write = 1'b1;

        #(1);
        if (wb_rf_reg_write !== 1'b1 || wb_fwd_data !== 32'hA5A5_5A5A || wb_retired_valid !== 1'b1) begin
            $display("[FAIL] WB stage failed to qualify write! reg_write=%b, fwd_data=0x%08h, retired_valid=%b",
                     wb_rf_reg_write, wb_fwd_data, wb_retired_valid);
            errors = errors + 1;
        end else begin
            $display("[PASS] WB successfully routed data 0x%08h to x%0d (Retired=1)", wb_rf_wdata, wb_rf_rd);
        end

        @(posedge clk); // Commit write to RegFile
        #(1);
        rf_raddr1 = 5'd5;
        #(1);
        if (rf_rdata1 !== 32'hA5A5_5A5A) begin
            $display("[FAIL] RegFile did not latch written value! Got: 0x%08h", rf_rdata1);
            errors = errors + 1;
        end else begin
            $display("[PASS] RegFile confirmed latched value: x5 = 0x%08h", rf_rdata1);
        end

        // --- TEST 2: Hardware Bubble Rejection (Flush/Reset) ---
        $display("\n--- TEST 2: Hardware Bubble Rejection (Opcode 7'b0000000) ---");
        @(negedge clk);
        mem_wb_wdata     = 32'hDEAD_BEEF;
        mem_wb_rd        = 5'd10;
        mem_wb_opcode    = 7'b0000000; // Hardware Bubble injected by flush
        mem_wb_reg_write = 1'b0;

        #(1);
        if (wb_retired_valid !== 1'b0 || wb_rf_reg_write !== 1'b0) begin
            $display("[FAIL] Hardware bubble falsely retired or wrote! retired_valid=%b, reg_write=%b",
                     wb_retired_valid, wb_rf_reg_write);
            errors = errors + 1;
        end else begin
            $display("[PASS] Hardware bubble cleanly suppressed: wb_retired_valid = 0, wb_rf_reg_write = 0");
        end

        // --- TEST 3: Software NOP Retirement (addi x0, x0, 0) ---
        $display("\n--- TEST 3: Software NOP Retirement (addi x0, x0, 0) ---");
        @(negedge clk);
        mem_wb_wdata     = 32'd0;
        mem_wb_rd        = 5'd0;         // rd = x0
        mem_wb_opcode    = 7'b0010011; // OPC_OP_IMM
        mem_wb_reg_write = 1'b1;         // ADDI has reg_write asserted

        #(1);
        if (wb_retired_valid !== 1'b1 || wb_rf_reg_write !== 1'b0) begin
            $display("[FAIL] Software NOP handling failed! retired_valid=%b (exp 1), reg_write=%b (exp 0)",
                     wb_retired_valid, wb_rf_reg_write);
            errors = errors + 1;
        end else begin
            $display("[PASS] Software NOP successfully retired (wb_retired_valid = 1) with x0 write suppressed");
        end

        // --- TEST 4: Defensive x0 Write Suppression ---
        $display("\n--- TEST 4: Defensive x0 Write Suppression Under Non-Zero Data ---");
        @(negedge clk);
        mem_wb_wdata     = 32'hFFFF_FFFF;
        mem_wb_rd        = 5'd0;
        mem_wb_opcode    = 7'b0110011;
        mem_wb_reg_write = 1'b1;

        #(1);
        if (wb_rf_reg_write !== 1'b0) begin
            $display("[FAIL] WB failed to suppress write enable for x0! wb_rf_reg_write=%b", wb_rf_reg_write);
            errors = errors + 1;
        end else begin
            $display("[PASS] WB defensively deasserted RegWrite for rd=0");
        end

        @(posedge clk);
        #(1);
        rf_raddr1 = 5'd0;
        #(1);
        if (rf_rdata1 !== 32'd0) begin
            $display("[FAIL] x0 register was overwritten! Got: 0x%08h", rf_rdata1);
            errors = errors + 1;
        end else begin
            $display("[PASS] x0 remains strictly immutable (0x00000000)");
        end

        // --- TEST 5: WB-to-ID Write-Through Hazard Bypass ---
        $display("\n--- TEST 5: Simultaneous WB-to-ID Write-Through Bypass ---");
        @(negedge clk);
        mem_wb_wdata     = 32'h1234_5678;
        mem_wb_rd        = 5'd12;
        mem_wb_opcode    = 7'b0000011; // LW
        mem_wb_reg_write = 1'b1;
        rf_raddr1        = 5'd12;        // Read port 1 points to x12 in same cycle

        #(1); // Combinational check before clock edge
        if (rf_rdata1 !== 32'h1234_5678) begin
            $display("[FAIL] RegFile write-through bypass failed! Read: 0x%08h, Expected: 0x12345678", rf_rdata1);
            errors = errors + 1;
        end else begin
            $display("[PASS] Combinational write-through bypass resolved: rdata1 = 0x%08h before clock edge", rf_rdata1);
        end

        @(posedge clk);
        #(CLK_PERIOD * 2);

        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 84 RISC-V WRITEBACK & REGFILE LOOP CLOSURE: PASSED");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule