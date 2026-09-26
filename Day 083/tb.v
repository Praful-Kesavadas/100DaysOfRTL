`timescale 1ns / 1ps

module tb_riscv_mem_stage();

    parameter CLK_PERIOD = 10;

    reg         clk;
    reg         nreset;
    reg         stall_wb;
    reg         flush_wb;

    reg  [31:0] ex_mem_alu_result;
    reg  [31:0] ex_mem_wdata;
    reg  [4:0]  ex_mem_rd;
    reg  [2:0]  ex_mem_funct3;
    reg  [6:0]  ex_mem_opcode;
    reg         ex_mem_reg_write;
    reg         ex_mem_mem_read;
    reg         ex_mem_mem_write;

    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0]  dmem_wstrb;
    wire        dmem_en;
    wire [31:0] dmem_rdata;

    wire        trap_load_misaligned;
    wire        trap_store_misaligned;

    wire [31:0] mem_wb_wdata;
    wire [4:0]  mem_wb_rd;
    wire [6:0]  mem_wb_opcode;
    wire        mem_wb_reg_write;

    integer errors = 0;

    // Instantiate MEM Stage UUT
    riscv_mem_stage u_mem_stage (
        .clk                  (clk),
        .nreset               (nreset),
        .stall_wb             (stall_wb),
        .flush_wb             (flush_wb),
        .ex_mem_alu_result    (ex_mem_alu_result),
        .ex_mem_wdata         (ex_mem_wdata),
        .ex_mem_rd            (ex_mem_rd),
        .ex_mem_funct3        (ex_mem_funct3),
        .ex_mem_opcode        (ex_mem_opcode),
        .ex_mem_reg_write     (ex_mem_reg_write),
        .ex_mem_mem_read      (ex_mem_mem_read),
        .ex_mem_mem_write     (ex_mem_mem_write),
        .dmem_addr            (dmem_addr),
        .dmem_wdata           (dmem_wdata),
        .dmem_wstrb           (dmem_wstrb),
        .dmem_en              (dmem_en),
        .dmem_rdata           (dmem_rdata),
        .trap_load_misaligned (trap_load_misaligned),
        .trap_store_misaligned(trap_store_misaligned),
        .mem_wb_wdata         (mem_wb_wdata),
        .mem_wb_rd            (mem_wb_rd),
        .mem_wb_opcode        (mem_wb_opcode),
        .mem_wb_reg_write     (mem_wb_reg_write)
    );

    // Instantiate Companion Data Memory
    riscv_data_mem #(.MEM_DEPTH(256)) u_data_mem (
        .clk   (clk),
        .en    (dmem_en),
        .wstrb (dmem_wstrb),
        .addr  (dmem_addr),
        .wdata (dmem_wdata),
        .rdata (dmem_rdata)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_riscv_mem_stage);

        clk               = 0;
        nreset            = 0;
        stall_wb          = 0;
        flush_wb          = 0;
        ex_mem_alu_result = 32'd0;
        ex_mem_wdata      = 32'd0;
        ex_mem_rd         = 5'd0;
        ex_mem_funct3     = 3'd0;
        ex_mem_opcode     = 7'b0000000;
        ex_mem_reg_write  = 0;
        ex_mem_mem_read   = 0;
        ex_mem_mem_write  = 0;

        #(CLK_PERIOD * 3);
        @(negedge clk);
        nreset = 1;

        $display("\n=======================================================================================================");
        $display("                   DAY 83: RISC-V MEMORY (MEM) STAGE VERIFICATION                                       ");
        $display("=======================================================================================================");

        // --- TEST 1: ALU Pass-Through (Non-Memory Instructions) ---
        $display("\n--- TEST 1: ALU Computation Pass-Through (ADD/SUB/etc.) ---");
        @(negedge clk);
        ex_mem_alu_result = 32'hDEAD_BEEF;
        ex_mem_rd         = 5'd10;
        ex_mem_reg_write  = 1'b1;
        ex_mem_mem_read   = 1'b0;
        ex_mem_mem_write  = 1'b0;

        @(posedge clk);
        #(1);
        if (mem_wb_wdata !== 32'hDEAD_BEEF || mem_wb_rd !== 5'd10 || mem_wb_reg_write !== 1'b1) begin
            $display("[FAIL] ALU bypass failed! Got wdata: 0x%08h, rd: %0d", mem_wb_wdata, mem_wb_rd);
            errors = errors + 1;
        end else begin
            $display("[PASS] ALU result 0x%08h cleanly latched to WB port", mem_wb_wdata);
        end

        // --- TEST 2: Word Store & Word Load (SW & LW) ---
        $display("\n--- TEST 2: Word Store & Word Load (SW & LW) ---");
        @(negedge clk);
        ex_mem_alu_result = 32'h0000_0040;
        ex_mem_wdata      = 32'h1234_5678;
        ex_mem_funct3     = 3'b010; // SW
        ex_mem_mem_write  = 1'b1;
        ex_mem_mem_read   = 1'b0;
        ex_mem_reg_write  = 1'b0;

        @(posedge clk);
        #(1);
        @(negedge clk);
        ex_mem_mem_write  = 1'b0;
        ex_mem_mem_read   = 1'b1;
        ex_mem_rd         = 5'd5;
        ex_mem_reg_write  = 1'b1;

        @(posedge clk);
        #(1);
        if (mem_wb_wdata !== 32'h1234_5678 || mem_wb_rd !== 5'd5) begin
            $display("[FAIL] LW failed! Got: 0x%08h, Expected: 0x12345678", mem_wb_wdata);
            errors = errors + 1;
        end else begin
            $display("[PASS] SW followed by LW verified: 0x%08h", mem_wb_wdata);
        end

        // --- TEST 3: Byte Steering across All 4 Lanes (SB) ---
        $display("\n--- TEST 3: Byte Steering & Strobe Verification (SB) ---");
        // Assemble word 0xDDCCBBAA at address 0x00000050
        @(negedge clk);
        ex_mem_funct3    = 3'b000; // SB
        ex_mem_mem_write = 1'b1;
        ex_mem_mem_read  = 1'b0;
        ex_mem_reg_write = 1'b0;

        ex_mem_alu_result = 32'h0000_0050; ex_mem_wdata = 32'h0000_00AA; @(posedge clk);
        @(negedge clk);
        ex_mem_alu_result = 32'h0000_0051; ex_mem_wdata = 32'h0000_00BB; @(posedge clk);
        @(negedge clk);
        ex_mem_alu_result = 32'h0000_0052; ex_mem_wdata = 32'h0000_00CC; @(posedge clk);
        @(negedge clk);
        ex_mem_alu_result = 32'h0000_0053; ex_mem_wdata = 32'h0000_00DD; @(posedge clk);

        @(negedge clk);
        ex_mem_mem_write  = 1'b0;
        ex_mem_mem_read   = 1'b1;
        ex_mem_alu_result = 32'h0000_0050;
        ex_mem_funct3     = 3'b010; // LW
        ex_mem_rd         = 5'd7;

        @(posedge clk);
        #(1);
        if (mem_wb_wdata !== 32'hDDCC_BBAA) begin
            $display("[FAIL] 4-byte assembly failed! Got: 0x%08h, Expected: 0xDDCCBBAA", mem_wb_wdata);
            errors = errors + 1;
        end else begin
            $display("[PASS] Byte writes assembled to full word: 0x%08h", mem_wb_wdata);
        end

        // --- TEST 4: Signed vs Unsigned Byte Loads (LB vs LBU) ---
        $display("\n--- TEST 4: Byte Sign Extension (LB vs LBU) ---");
        // Read byte at 0x50 (0xAA = 8'b10101010 -> MSB is 1)
        @(negedge clk);
        ex_mem_alu_result = 32'h0000_0050;
        ex_mem_funct3     = 3'b000; // LB
        ex_mem_mem_read   = 1'b1;
        ex_mem_rd         = 5'd1;

        @(posedge clk);
        #(1);
        if (mem_wb_wdata !== 32'hFFFF_FFAA) begin
            $display("[FAIL] LB sign-extension failed! Got: 0x%08h, Expected: 0xFFFFFFAA", mem_wb_wdata);
            errors = errors + 1;
        end else begin
            $display("[PASS] LB signed extension: 0xAA -> 0x%08h", mem_wb_wdata);
        end

        @(negedge clk);
        ex_mem_funct3 = 3'b100; // LBU
        @(posedge clk);
        #(1);
        if (mem_wb_wdata !== 32'h0000_00AA) begin
            $display("[FAIL] LBU zero-extension failed! Got: 0x%08h, Expected: 0x000000AA", mem_wb_wdata);
            errors = errors + 1;
        end else begin
            $display("[PASS] LBU unsigned extension: 0xAA -> 0x%08h", mem_wb_wdata);
        end

        // --- TEST 5: Aligned Halfword Loads (LH vs LHU) ---
        $display("\n--- TEST 5: Aligned Halfword Sign Extension (LH vs LHU) ---");
        // Upper halfword at 0x52 contains 0xDDCC (MSB of 0xDD is 1)
        // Tests byte_offset[1] == 1 selection and 16-bit sign-extension
        @(negedge clk);
        ex_mem_alu_result = 32'h0000_0052; // Aligned halfword offset 2
        ex_mem_funct3     = 3'b001;        // LH
        ex_mem_mem_read   = 1'b1;
        ex_mem_mem_write  = 1'b0;
        ex_mem_reg_write  = 1'b1;
        ex_mem_rd         = 5'd2;

        @(posedge clk);
        #(1);
        if (mem_wb_wdata !== 32'hFFFF_DDCC) begin
            $display("[FAIL] LH sign-extension failed! Got: 0x%08h, Expected: 0xFFFFDDCC", mem_wb_wdata);
            errors = errors + 1;
        end else begin
            $display("[PASS] LH upper-halfword signed extension: 0xDDCC -> 0x%08h", mem_wb_wdata);
        end

        @(negedge clk);
        ex_mem_funct3 = 3'b101; // LHU
        @(posedge clk);
        #(1);
        if (mem_wb_wdata !== 32'h0000_DDCC) begin
            $display("[FAIL] LHU zero-extension failed! Got: 0x%08h, Expected: 0x0000DDCC", mem_wb_wdata);
            errors = errors + 1;
        end else begin
            $display("[PASS] LHU upper-halfword unsigned extension: 0xDDCC -> 0x%08h", mem_wb_wdata);
        end

        // Lower halfword at 0x50 contains 0xBBAA (MSB of 0xBB is 1)
        // Tests byte_offset[1] == 0 selection
        @(negedge clk);
        ex_mem_alu_result = 32'h0000_0050; // Aligned halfword offset 0
        ex_mem_funct3     = 3'b001;        // LH
        @(posedge clk);
        #(1);
        if (mem_wb_wdata !== 32'hFFFF_BBAA) begin
            $display("[FAIL] LH lower-halfword failed! Got: 0x%08h, Expected: 0xFFFFBBAA", mem_wb_wdata);
            errors = errors + 1;
        end else begin
            $display("[PASS] LH lower-halfword signed extension: 0xBBAA -> 0x%08h", mem_wb_wdata);
        end

        // --- TEST 6: Address Misalignment Traps & Strobe Zeroing ---
        $display("\n--- TEST 6: Misalignment Detection & Strobe Zeroing ---");
        // Test 6a: Misaligned SW to 0x0000_0061 (offset 1)
        @(negedge clk);
        ex_mem_alu_result = 32'h0000_0061;
        ex_mem_wdata      = 32'hA5A5_A5A5;
        ex_mem_funct3     = 3'b010; // SW
        ex_mem_mem_write  = 1'b1;
        ex_mem_mem_read   = 1'b0;

        #(1);
        if (trap_store_misaligned !== 1'b1 || dmem_wstrb !== 4'b0000 || dmem_en !== 1'b0) begin
            $display("[FAIL] Misaligned SW was not trapped! trap=%b, wstrb=%b, dmem_en=%b",
                     trap_store_misaligned, dmem_wstrb, dmem_en);
            errors = errors + 1;
        end else begin
            $display("[PASS] Misaligned SW trapped: trap_store_misaligned=1, dmem_wstrb=0000, dmem_en=0");
        end

        // Test 6b: Misaligned LH to 0x0000_0063 (offset 3)
        @(negedge clk);
        ex_mem_alu_result = 32'h0000_0063;
        ex_mem_funct3     = 3'b001; // LH
        ex_mem_mem_write  = 1'b0;
        ex_mem_mem_read   = 1'b1;
        ex_mem_rd         = 5'd8;
        ex_mem_reg_write  = 1'b1;

        #(1);
        if (trap_load_misaligned !== 1'b1 || dmem_en !== 1'b0) begin
            $display("[FAIL] Misaligned LH was not trapped! trap=%b, dmem_en=%b",
                     trap_load_misaligned, dmem_en);
            errors = errors + 1;
        end else begin
            $display("[PASS] Misaligned LH trapped: trap_load_misaligned=1, dmem_en=0");
        end

        @(posedge clk);
        #(1);
        if (mem_wb_reg_write !== 1'b0) begin
            $display("[FAIL] mem_wb_reg_write remained active during trapped access!");
            errors = errors + 1;
        end else begin
            $display("[PASS] RegWrite suppressed in MEM/WB register during trap condition");
        end

        // --- TEST 7: Pipeline Stall & Flush ---
        $display("\n--- TEST 7: MEM/WB Register Stall & Flush ---");
        @(negedge clk);
        stall_wb          = 1'b1;
        ex_mem_alu_result = 32'hCAFE_CAFE;
        ex_mem_mem_read   = 1'b0;
        ex_mem_mem_write  = 1'b0;
        ex_mem_reg_write  = 1'b1;
        ex_mem_rd         = 5'd20;

        @(posedge clk);
        #(1);
        if (mem_wb_rd === 5'd20) begin
            $display("[FAIL] MEM/WB drifted during stall_wb!");
            errors = errors + 1;
        end else begin
            $display("[PASS] MEM/WB held state during stall_wb");
        end

        @(negedge clk);
        stall_wb = 1'b0;
        flush_wb = 1'b1;

        @(posedge clk);
        #(1);
        if (mem_wb_reg_write !== 1'b0 || mem_wb_rd !== 5'd0) begin
            $display("[FAIL] Flush failed to inject bubble! reg_write=%b, rd=%0d", mem_wb_reg_write, mem_wb_rd);
            errors = errors + 1;
        end else begin
            $display("[PASS] MEM/WB successfully cleared to NOP bubble on flush_wb");
        end

        // --- TEST 8: Store Squashed by Concurrent Flush (Memory Immutability) ---
        $display("\n--- TEST 8: Store Squashed Concurrently by flush_wb ---");
        @(negedge clk);
        flush_wb          = 1'b0;
        ex_mem_alu_result = 32'h0000_0070;
        ex_mem_wdata      = 32'h1122_3344;
        ex_mem_funct3     = 3'b010; // SW
        ex_mem_mem_write  = 1'b1;
        ex_mem_mem_read   = 1'b0;
        ex_mem_reg_write  = 1'b0;

        @(posedge clk);
        #(1);

        // Attempt squashed store with flush_wb asserted
        @(negedge clk);
        flush_wb          = 1'b1;
        ex_mem_alu_result = 32'h0000_0070;
        ex_mem_wdata      = 32'hBAD0_C0FF;
        ex_mem_funct3     = 3'b010; // SW
        ex_mem_mem_write  = 1'b1;

        #(1);
        if (dmem_en !== 1'b0 || dmem_wstrb !== 4'b0000) begin
            $display("[FAIL] Flushed store failed to suppress strobes! dmem_en=%b, dmem_wstrb=%b",
                     dmem_en, dmem_wstrb);
            errors = errors + 1;
        end

        @(posedge clk);
        #(1);
        flush_wb         = 1'b0;
        ex_mem_mem_write = 1'b0;

        // Verify memory was not overwritten
        @(negedge clk);
        ex_mem_alu_result = 32'h0000_0070;
        ex_mem_mem_read   = 1'b1;
        ex_mem_funct3     = 3'b010; // LW
        ex_mem_rd         = 5'd12;
        ex_mem_reg_write  = 1'b1;

        @(posedge clk);
        #(1);
        if (mem_wb_wdata !== 32'h1122_3344) begin
            $display("[FAIL] Memory corrupted during squashed store! Got: 0x%08h, Expected: 0x11223344", mem_wb_wdata);
            errors = errors + 1;
        end else begin
            $display("[PASS] Memory remained immutable across squashed store: 0x%08h", mem_wb_wdata);
        end

        // --- TEST 9: Misalignment Trap Suppression under Concurrent Flush ---
        $display("\n--- TEST 9: Misalignment Trap Suppression during flush_wb ---");
        @(negedge clk);
        flush_wb          = 1'b1;
        ex_mem_alu_result = 32'h0000_0071; // Misaligned store
        ex_mem_funct3     = 3'b010;        // SW
        ex_mem_mem_write  = 1'b1;
        ex_mem_mem_read   = 1'b0;

        #(1);
        if (trap_store_misaligned !== 1'b0 || dmem_en !== 1'b0) begin
            $display("[FAIL] Phantom trap_store_misaligned fired under flush! trap=%b", trap_store_misaligned);
            errors = errors + 1;
        end else begin
            $display("[PASS] Phantom store trap suppressed under flush_wb: trap_store_misaligned=0");
        end

        @(negedge clk);
        ex_mem_alu_result = 32'h0000_0073; // Misaligned load
        ex_mem_funct3     = 3'b001;        // LH
        ex_mem_mem_write  = 1'b0;
        ex_mem_mem_read   = 1'b1;

        #(1);
        if (trap_load_misaligned !== 1'b0 || dmem_en !== 1'b0) begin
            $display("[FAIL] Phantom trap_load_misaligned fired under flush! trap=%b", trap_load_misaligned);
            errors = errors + 1;
        end else begin
            $display("[PASS] Phantom load trap suppressed under flush_wb: trap_load_misaligned=0");
        end

        @(posedge clk);
        #(CLK_PERIOD * 5);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 83 RISC-V MEM STAGE VERIFICATION SUCCESSFUL");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule