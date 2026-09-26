`timescale 1ns / 1ps

module tb_riscv_ex_stage();

    parameter CLK_PERIOD = 10;

    reg         clk;
    reg         nreset;
    reg         stall_mem;
    reg         flush_mem;

    // Forwarding Controls
    reg  [1:0]  forward_a;
    reg  [1:0]  forward_b;
    reg  [31:0] ex_mem_fwd_data;
    reg  [31:0] mem_wb_fwd_data;

    // Inputs from ID/EX
    reg  [31:0] id_ex_pc;
    reg  [31:0] id_ex_pc_plus_4;
    reg  [31:0] id_ex_rdata1;
    reg  [31:0] id_ex_rdata2;
    reg  [31:0] id_ex_imm;
    reg  [4:0]  id_ex_rs1;
    reg  [4:0]  id_ex_rs2;
    reg         id_ex_rs1_valid;
    reg         id_ex_rs2_valid;
    reg  [4:0]  id_ex_rd;
    reg  [2:0]  id_ex_funct3;
    reg  [6:0]  id_ex_funct7;
    reg  [6:0]  id_ex_opcode;

    // Outputs
    wire        pc_src_ex;
    wire [31:0] pc_target_ex;
    wire [31:0] ex_mem_pc_plus_4;
    wire [31:0] ex_mem_alu_result;
    wire [31:0] ex_mem_wdata;
    wire [4:0]  ex_mem_rd;
    wire [2:0]  ex_mem_funct3;
    wire [6:0]  ex_mem_opcode;
    wire        ex_mem_reg_write;
    wire        ex_mem_mem_read;
    wire        ex_mem_mem_write;

    integer errors = 0;

    // Instantiate UUT
    riscv_ex_stage uut (
        .clk               (clk),
        .nreset            (nreset),
        .stall_mem         (stall_mem),
        .flush_mem         (flush_mem),
        .forward_a         (forward_a),
        .forward_b         (forward_b),
        .ex_mem_fwd_data   (ex_mem_fwd_data),
        .mem_wb_fwd_data   (mem_wb_fwd_data),
        .id_ex_pc          (id_ex_pc),
        .id_ex_pc_plus_4   (id_ex_pc_plus_4),
        .id_ex_rdata1      (id_ex_rdata1),
        .id_ex_rdata2      (id_ex_rdata2),
        .id_ex_imm         (id_ex_imm),
        .id_ex_rs1         (id_ex_rs1),
        .id_ex_rs2         (id_ex_rs2),
        .id_ex_rs1_valid   (id_ex_rs1_valid),
        .id_ex_rs2_valid   (id_ex_rs2_valid),
        .id_ex_rd          (id_ex_rd),
        .id_ex_funct3      (id_ex_funct3),
        .id_ex_funct7      (id_ex_funct7),
        .id_ex_opcode      (id_ex_opcode),
        .pc_src_ex         (pc_src_ex),
        .pc_target_ex      (pc_target_ex),
        .ex_mem_pc_plus_4  (ex_mem_pc_plus_4),
        .ex_mem_alu_result (ex_mem_alu_result),
        .ex_mem_wdata      (ex_mem_wdata),
        .ex_mem_rd         (ex_mem_rd),
        .ex_mem_funct3     (ex_mem_funct3),
        .ex_mem_opcode     (ex_mem_opcode),
        .ex_mem_reg_write  (ex_mem_reg_write),
        .ex_mem_mem_read   (ex_mem_mem_read),
        .ex_mem_mem_write  (ex_mem_mem_write)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_riscv_ex_stage);

        clk             = 0;
        nreset          = 0;
        stall_mem       = 0;
        flush_mem       = 0;
        forward_a       = 2'b00;
        forward_b       = 2'b00;
        ex_mem_fwd_data = 32'd0;
        mem_wb_fwd_data = 32'd0;
        id_ex_pc        = 32'h0000_1000;
        id_ex_pc_plus_4 = 32'h0000_1004;
        id_ex_rdata1    = 32'd0;
        id_ex_rdata2    = 32'd0;
        id_ex_imm       = 32'd0;
        id_ex_rs1       = 5'd0;
        id_ex_rs2       = 5'd0;
        id_ex_rs1_valid = 1'b0;
        id_ex_rs2_valid = 1'b0;
        id_ex_rd        = 5'd0;
        id_ex_funct3    = 3'd0;
        id_ex_funct7    = 7'd0;
        id_ex_opcode    = 7'b0000000; // NOP

        #(CLK_PERIOD * 3);
        @(negedge clk);
        nreset = 1;

        $display("\n=======================================================================================================");
        $display("                   DAY 82: RISC-V EXECUTE (EX) STAGE & FORWARDING VERIFICATION                         ");
        $display("=======================================================================================================");

        // --- TEST 1: Baseline Arithmetic (ADD & SUB without forwarding) ---
        $display("\n--- TEST 1: ALU Arithmetic (ADD & SUB) ---");
        @(negedge clk);
        id_ex_opcode    = 7'b0110011; // R-type
        id_ex_funct3    = 3'b000;
        id_ex_funct7    = 7'b0100000; // SUB
        id_ex_rdata1    = 32'd20;
        id_ex_rdata2    = 32'd50;
        id_ex_rd        = 5'd3;
        forward_a       = 2'b00;
        forward_b       = 2'b00;

        @(posedge clk);
        #(1);
        if (ex_mem_alu_result !== 32'hFFFFFFE2 || ex_mem_reg_write !== 1'b1) begin
            $display("[FAIL] SUB failed! Got: 0x%08h, Expected: 0xFFFFFFE2", ex_mem_alu_result);
            errors = errors + 1;
        end else begin
            $display("[PASS] SUB without bypass: 20 - 50 = -30 (0x%08h)", ex_mem_alu_result);
        end

        // --- TEST 2: EX/MEM (1-Cycle RAW) Bypass Forwarding into Operand A ---
        $display("\n--- TEST 2: EX/MEM (1-Cycle RAW) Bypass to ALU Operand A ---");
        // Instruction in EX needs result from instruction currently in EX/MEM
        @(negedge clk);
        id_ex_opcode    = 7'b0010011; // addi x4, x1, 10
        id_ex_funct3    = 3'b000;
        id_ex_rdata1    = 32'd0;      // Stale data in ID/EX
        id_ex_imm       = 32'd10;
        id_ex_rd        = 5'd4;
        forward_a       = 2'b10;      // Select EX/MEM bypass
        ex_mem_fwd_data = 32'd100;    // Fresh result from stage ahead

        @(posedge clk);
        #(1);
        if (ex_mem_alu_result !== 32'd110) begin
            $display("[FAIL] EX/MEM forward_a failed! Got: %0d, Expected: 110", ex_mem_alu_result);
            errors = errors + 1;
        end else begin
            $display("[PASS] EX/MEM forwarded: 100 + 10 = %0d", ex_mem_alu_result);
        end

        // --- TEST 3: MEM/WB (2-Cycle RAW) Bypass Forwarding into Operand B ---
        $display("\n--- TEST 3: MEM/WB (2-Cycle RAW) Bypass to ALU Operand B ---");
        @(negedge clk);
        id_ex_opcode    = 7'b0110011; // add x5, x1, x2
        id_ex_funct3    = 3'b000;
        id_ex_funct7    = 7'b0000000;
        id_ex_rdata1    = 32'd50;     // Valid from ID/EX
        id_ex_rdata2    = 32'd0;      // Stale data
        id_ex_rd        = 5'd5;
        forward_a       = 2'b00;
        forward_b       = 2'b01;      // Select MEM/WB bypass
        mem_wb_fwd_data = 32'd25;     // Fresh result from WB stage

        @(posedge clk);
        #(1);
        if (ex_mem_alu_result !== 32'd75) begin
            $display("[FAIL] MEM/WB forward_b failed! Got: %0d, Expected: 75", ex_mem_alu_result);
            errors = errors + 1;
        end else begin
            $display("[PASS] MEM/WB forwarded: 50 + 25 = %0d", ex_mem_alu_result);
        end

        // --- TEST 4: Forwarding into Branch Comparator ---
        $display("\n--- TEST 4: Forwarding into Branch Comparator ---");
        @(negedge clk);
        id_ex_pc        = 32'h0000_0100;
        id_ex_pc_plus_4 = 32'h0000_0104;
        id_ex_opcode    = 7'b1100011; // beq x1, x2, +16
        id_ex_funct3    = 3'b000;
        id_ex_imm       = 32'd16;
        id_ex_rdata1    = 32'd111;    // Stale: Not equal
        id_ex_rdata2    = 32'd222;    // Stale: Not equal
        forward_a       = 2'b10;      // Forward 500 from EX/MEM
        forward_b       = 2'b01;      // Forward 500 from MEM/WB
        ex_mem_fwd_data = 32'd500;
        mem_wb_fwd_data = 32'd500;

        #(1); // Combinational check before clock edge
        if (pc_src_ex !== 1'b1 || pc_target_ex !== 32'h0000_0110) begin
            $display("[FAIL] Forwarded BEQ comparison failed! pc_src_ex=%b, target=0x%08h",
                     pc_src_ex, pc_target_ex);
            errors = errors + 1;
        end else begin
            $display("[PASS] Forwarded BEQ matched (500 == 500), pc_src_ex=1, Target=0x%08h", pc_target_ex);
        end

        // --- TEST 5: Forwarding into Store Data (ex_mem_wdata) ---
        $display("\n--- TEST 5: Forwarding into Store Write-Data Bus ---");
        @(negedge clk);
        forward_a       = 2'b00;
        forward_b       = 2'b10;      // Forward store payload from EX/MEM
        ex_mem_fwd_data = 32'hCAFE_BABE;
        id_ex_opcode    = 7'b0100011; // sw x2, 4(x1)
        id_ex_rdata1    = 32'h0000_2000; // Base address
        id_ex_rdata2    = 32'h0000_0000; // Stale data
        id_ex_imm       = 32'd4;
        id_ex_rd        = 5'd0;

        @(posedge clk);
        #(1);
        if (ex_mem_wdata !== 32'hCAFE_BABE || ex_mem_alu_result !== 32'h0000_2004) begin
            $display("[FAIL] Store forwarding failed! wdata=0x%08h (exp 0xCAFEBABE), addr=0x%08h",
                     ex_mem_wdata, ex_mem_alu_result);
            errors = errors + 1;
        end else begin
            $display("[PASS] Store data successfully forwarded: 0x%08h to Address 0x%08h",
                     ex_mem_wdata, ex_mem_alu_result);
        end

        // --- TEST 6: Pipeline Stall & Flush ---
        $display("\n--- TEST 6: EX/MEM Stall & Flush ---");
        @(negedge clk);
        stall_mem = 1'b1;
        id_ex_rd  = 5'd15;

        @(posedge clk);
        #(1);
        if (ex_mem_rd !== 5'd0) begin
            $display("[FAIL] EX/MEM drifted during stall!");
            errors = errors + 1;
        end else begin
            $display("[PASS] EX/MEM held state across stall_mem!");
        end

        @(negedge clk);
        stall_mem = 1'b0;
        flush_mem = 1'b1;

        @(posedge clk);
        #(1);
        if (ex_mem_reg_write !== 1'b0) begin
            $display("[FAIL] Flush failed to insert bubble!");
            errors = errors + 1;
        end else begin
            $display("[PASS] EX/MEM flushed to NOP bubble!");
        end

        #(CLK_PERIOD * 5);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 82 RISC-V EX STAGE & FORWARDING VERIFIED");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule