`timescale 1ns / 1ps

module tb_riscv_id_stage();

    parameter CLK_PERIOD = 10;

    reg         clk;
    reg         nreset;

    // Controls
    reg         stall_ex;
    reg         flush_ex;

    // Inputs from IF/ID
    reg  [31:0] if_id_pc;
    reg  [31:0] if_id_pc_plus_4;
    reg  [31:0] if_id_instr;

    // Inputs from WB
    reg         wb_reg_write;
    reg  [4:0]  wb_rd;
    reg  [31:0] wb_wdata;

    // Outputs from ID Stage
    wire [4:0]  id_rs1;
    wire [4:0]  id_rs2;
    wire        id_rs1_valid;
    wire        id_rs2_valid;

    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_pc_plus_4;
    wire [31:0] id_ex_rdata1;
    wire [31:0] id_ex_rdata2;
    wire [31:0] id_ex_imm;
    wire [4:0]  id_ex_rs1;
    wire [4:0]  id_ex_rs2;
    wire        id_ex_rs1_valid;
    wire        id_ex_rs2_valid;
    wire [4:0]  id_ex_rd;
    wire [2:0]  id_ex_funct3;
    wire [6:0]  id_ex_funct7;
    wire [6:0]  id_ex_opcode;

    integer errors = 0;

    // Instantiate UUT
    riscv_id_stage uut (
        .clk             (clk),
        .nreset          (nreset),
        .stall_ex        (stall_ex),
        .flush_ex        (flush_ex),
        .if_id_pc        (if_id_pc),
        .if_id_pc_plus_4 (if_id_pc_plus_4),
        .if_id_instr     (if_id_instr),
        .wb_reg_write    (wb_reg_write),
        .wb_rd           (wb_rd),
        .wb_wdata        (wb_wdata),
        .id_rs1          (id_rs1),
        .id_rs2          (id_rs2),
        .id_rs1_valid    (id_rs1_valid),
        .id_rs2_valid    (id_rs2_valid),
        .id_ex_pc        (id_ex_pc),
        .id_ex_pc_plus_4 (id_ex_pc_plus_4),
        .id_ex_rdata1    (id_ex_rdata1),
        .id_ex_rdata2    (id_ex_rdata2),
        .id_ex_imm       (id_ex_imm),
        .id_ex_rs1       (id_ex_rs1),
        .id_ex_rs2       (id_ex_rs2),
        .id_ex_rs1_valid (id_ex_rs1_valid),
        .id_ex_rs2_valid (id_ex_rs2_valid),
        .id_ex_rd        (id_ex_rd),
        .id_ex_funct3    (id_ex_funct3),
        .id_ex_funct7    (id_ex_funct7),
        .id_ex_opcode    (id_ex_opcode)
    );

    // Clock Generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_riscv_id_stage);

        clk             = 0;
        nreset          = 0;
        stall_ex        = 0;
        flush_ex        = 0;
        if_id_pc        = 32'd0;
        if_id_pc_plus_4 = 32'd4;
        if_id_instr     = 32'h0000_0000; // NOP
        wb_reg_write    = 0;
        wb_rd           = 5'd0;
        wb_wdata        = 32'd0;

        #(CLK_PERIOD * 3);
        @(negedge clk);
        nreset = 1;

        $display("\n=======================================================================================================");
        $display("                   DAY 81: RISC-V INSTRUCTION DECODE (ID) STAGE VERIFICATION                           ");
        $display("=======================================================================================================");

        // --- TEST 1: Register File Writes, x0 Hardwiring & Validity Flag Behavior ---
        $display("\n--- TEST 1: Register File Writes, x0 Hardwiring & Validity Qualifiers ---");
        // Write 0xDEADBEEF to x5
        @(negedge clk);
        wb_reg_write = 1'b1;
        wb_rd        = 5'd5;
        wb_wdata     = 32'hDEADBEEF;

        // Try to overwrite x0 with 0xCAFEBABE
        @(negedge clk);
        wb_rd        = 5'd0;
        wb_wdata     = 32'hCAFEBABE;

        @(negedge clk);
        wb_reg_write = 1'b0;

        // Feed instruction: add x6, x5, x0 (R-Type: rs1=x5, rs2=x0)
        if_id_instr  = {7'b0000000, 5'd0, 5'd5, 3'b000, 5'd6, 7'b0110011};

        #(1);
        // Verify combinational validity: rs1(x5) is valid; rs2(x0) must be INVALID (0)
        if (id_rs1_valid !== 1'b1 || id_rs2_valid !== 1'b0) begin
            $display("[FAIL] Combinational valid mismatch! id_rs1_valid=%b (exp 1), id_rs2_valid=%b (exp 0)",
                     id_rs1_valid, id_rs2_valid);
            errors = errors + 1;
        end else begin
            $display("[PASS] Combinational validity: rs1(x5) valid=1, rs2(x0) valid=0 (suppressed)");
        end

        @(posedge clk);
        #(1);
        if (id_ex_rdata1 !== 32'hDEADBEEF) begin
            $display("[FAIL] Read x5 failed! Got: 0x%08h, Expected: 0xDEADBEEF", id_ex_rdata1);
            errors = errors + 1;
        end else begin
            $display("[PASS] Read x5 succeeded (0xDEADBEEF)");
        end

        if (id_ex_rdata2 !== 32'h0000_0000) begin
            $display("[FAIL] x0 was modified! Got: 0x%08h, Expected: 0x00000000", id_ex_rdata2);
            errors = errors + 1;
        end else begin
            $display("[PASS] x0 correctly invariant at 0x00000000");
        end

        // Verify registered validity in ID/EX
        if (id_ex_rs1_valid !== 1'b1 || id_ex_rs2_valid !== 1'b0) begin
            $display("[FAIL] Registered valid mismatch! id_ex_rs1_valid=%b, id_ex_rs2_valid=%b",
                     id_ex_rs1_valid, id_ex_rs2_valid);
            errors = errors + 1;
        end else begin
            $display("[PASS] Registered validity: id_ex_rs1_valid=1, id_ex_rs2_valid=0");
        end

        // --- TEST 2: Internal RegFile WB Bypass ---
        $display("\n--- TEST 2: Internal RegFile Bypass Forwarding ---");
        @(negedge clk);
        wb_reg_write = 1'b1;
        wb_rd        = 5'd10;
        wb_wdata     = 32'hA5A55A5A;
        // Instruction: add x1, x10, x0
        if_id_instr  = {7'b0000000, 5'd0, 5'd10, 3'b000, 5'd1, 7'b0110011};

        #(1);
        if (uut.u_regfile.rdata1 !== 32'hA5A55A5A) begin
            $display("[FAIL] Internal bypass failed! Combinational rdata1: 0x%08h", uut.u_regfile.rdata1);
            errors = errors + 1;
        end else begin
            $display("[PASS] Internal RegFile bypass forwarded write data combinationally in same cycle!");
        end

        @(posedge clk);
        #(1);
        wb_reg_write = 1'b0;

        // --- TEST 3: Immediate Generator & Field Validity Across All RV32I Formats ---
        $display("\n--- TEST 3: Immediate Generator & Register Validity Across Formats ---");

        // 3a. I-Type: addi x1, x2, -42 (rs1=x2, imm=-42)
        // Note: instr[24:20] contains immediate bits 5'b00110 (=6), NOT rs2!
        // instr = {12'hFA6, 5'd2, 3'b000, 5'd1, 7'b0010011} = 0xFA610093
        @(negedge clk);
        if_id_instr = 32'hFA610093;

        #(1);
        if (id_rs1_valid !== 1'b1 || id_rs2_valid !== 1'b0) begin
            $display("[FAIL] I-Type validity error! id_rs1_valid=%b (exp 1), id_rs2_valid=%b (exp 0)",
                     id_rs1_valid, id_rs2_valid);
            errors = errors + 1;
        end else begin
            $display("[PASS] I-Type validity: rs1(x2) valid=1, rs2 immediate bits suppressed (valid=0)");
        end

        @(posedge clk);
        #(1);
        if (id_ex_imm !== 32'hFFFFFFA6 || id_ex_rs1_valid !== 1'b1 || id_ex_rs2_valid !== 1'b0) begin
            $display("[FAIL] I-Type decode/pipeline latch error! Imm: 0x%08h, v1=%b, v2=%b",
                     id_ex_imm, id_ex_rs1_valid, id_ex_rs2_valid);
            errors = errors + 1;
        end else begin
            $display("[PASS] I-Type Registered: Imm = -90 (0x%08h), rs1_valid=1, rs2_valid=0", id_ex_imm);
        end

        // 3b. S-Type: sw x5, -8(x2) (Uses rs1=x2 and rs2=x5)
        // instr = 0xFE512C23
        @(negedge clk);
        if_id_instr = 32'hFE512C23;

        #(1);
        if (id_rs1_valid !== 1'b1 || id_rs2_valid !== 1'b1) begin
            $display("[FAIL] S-Type validity error! id_rs1_valid=%b, id_rs2_valid=%b (exp 1, 1)",
                     id_rs1_valid, id_rs2_valid);
            errors = errors + 1;
        end

        @(posedge clk);
        #(1);
        if (id_ex_imm !== 32'hFFFFFFF8 || id_ex_rs1_valid !== 1'b1 || id_ex_rs2_valid !== 1'b1) begin
            $display("[FAIL] S-Type decode error! Imm: 0x%08h, v1=%b, v2=%b",
                     id_ex_imm, id_ex_rs1_valid, id_ex_rs2_valid);
            errors = errors + 1;
        end else begin
            $display("[PASS] S-Type Registered: Imm = -8 (0x%08h), rs1_valid=1, rs2_valid=1", id_ex_imm);
        end

        // 3c. B-Type: beq x1, x2, -16 (Branches compare rs1=x1 and rs2=x2)
        // instr = 0xFE2088E3
        @(negedge clk);
        if_id_instr = 32'hFE2088E3;

        #(1);
        if (id_rs1_valid !== 1'b1 || id_rs2_valid !== 1'b1) begin
            $display("[FAIL] B-Type validity error! id_rs1_valid=%b, id_rs2_valid=%b (exp 1, 1)",
                     id_rs1_valid, id_rs2_valid);
            errors = errors + 1;
        end

        @(posedge clk);
        #(1);
        if (id_ex_imm !== 32'hFFFFFFF0 || id_ex_rs1_valid !== 1'b1 || id_ex_rs2_valid !== 1'b1) begin
            $display("[FAIL] B-Type decode error! Imm: 0x%08h, v1=%b, v2=%b",
                     id_ex_imm, id_ex_rs1_valid, id_ex_rs2_valid);
            errors = errors + 1;
        end else begin
            $display("[PASS] B-Type Registered: Imm = -16 (0x%08h), rs1_valid=1, rs2_valid=1", id_ex_imm);
        end

        // 3d. U-Type: lui x3, 0x12345 (No source registers read)
        // instr = 0x123451B7
        @(negedge clk);
        if_id_instr = 32'h123451B7;

        #(1);
        if (id_rs1_valid !== 1'b0 || id_rs2_valid !== 1'b0) begin
            $display("[FAIL] U-Type validity error! id_rs1_valid=%b, id_rs2_valid=%b (exp 0, 0)",
                     id_rs1_valid, id_rs2_valid);
            errors = errors + 1;
        end

        @(posedge clk);
        #(1);
        if (id_ex_imm !== 32'h12345000 || id_ex_rs1_valid !== 1'b0 || id_ex_rs2_valid !== 1'b0) begin
            $display("[FAIL] U-Type decode error! Imm: 0x%08h, v1=%b, v2=%b",
                     id_ex_imm, id_ex_rs1_valid, id_ex_rs2_valid);
            errors = errors + 1;
        end else begin
            $display("[PASS] U-Type Registered: Imm = 0x%08h, rs1_valid=0, rs2_valid=0", id_ex_imm);
        end

        // 3e. J-Type: jal x1, -2048 (No source registers read)
        // instr = 0x801FF0EF
        @(negedge clk);
        if_id_instr = 32'h801FF0EF;

        #(1);
        if (id_rs1_valid !== 1'b0 || id_rs2_valid !== 1'b0) begin
            $display("[FAIL] J-Type validity error! id_rs1_valid=%b, id_rs2_valid=%b (exp 0, 0)",
                     id_rs1_valid, id_rs2_valid);
            errors = errors + 1;
        end

        @(posedge clk);
        #(1);
        if (id_ex_imm !== 32'hFFFFF800 || id_ex_rs1_valid !== 1'b0 || id_ex_rs2_valid !== 1'b0) begin
            $display("[FAIL] J-Type decode error! Imm: 0x%08h, v1=%b, v2=%b",
                     id_ex_imm, id_ex_rs1_valid, id_ex_rs2_valid);
            errors = errors + 1;
        end else begin
            $display("[PASS] J-Type Registered: Imm = -2048 (0x%08h), rs1_valid=0, rs2_valid=0", id_ex_imm);
        end

        // --- TEST 4: ID/EX Register Stall & Flush Behavior ---
        $display("\n--- TEST 4: ID/EX Pipeline Stall & Flush ---");
        @(negedge clk);
        stall_ex    = 1'b1;
        // Present an R-type (add x1, x2, x3) on IF/ID while pipeline is stalled
        if_id_instr = {7'b0000000, 5'd3, 5'd2, 3'b000, 5'd1, 7'b0110011};

        @(posedge clk);
        #(1);
        // During stall, the register must hold the previous J-type values (imm = -2048, valid = 0)
        if (id_ex_imm !== 32'hFFFFF800 || id_ex_rs1_valid !== 1'b0 || id_ex_rs2_valid !== 1'b0) begin
            $display("[FAIL] ID/EX drifted during stall! Imm: 0x%08h, rs1_v=%b, rs2_v=%b",
                     id_ex_imm, id_ex_rs1_valid, id_ex_rs2_valid);
            errors = errors + 1;
        end else begin
            $display("[PASS] Pipeline correctly held previous state and validity across stall_ex!");
        end

        @(negedge clk);
        stall_ex = 1'b0;
        flush_ex = 1'b1; // Trigger branch misprediction flush

        @(posedge clk);
        #(1);
        if (id_ex_opcode !== 7'b0000000 || id_ex_rd !== 5'd0 ||
            id_ex_rs1_valid !== 1'b0    || id_ex_rs2_valid !== 1'b0) begin
            $display("[FAIL] Flush failed to inject NOP bubble or clear valids! Opcode: 0x%02h, rd: %0d, v1=%b, v2=%b",
                     id_ex_opcode, id_ex_rd, id_ex_rs1_valid, id_ex_rs2_valid);
            errors = errors + 1;
        end else begin
            $display("[PASS] Pipeline register successfully cleared to NOP bubble with zeroed valids on flush_ex!");
        end

        #(CLK_PERIOD * 5);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 81 RISC-V ID STAGE VERIFICATION SUCCESSFUL: 0 ERRORS DETECTED! (PASSED)");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule