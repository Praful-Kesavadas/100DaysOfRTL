`timescale 1ns / 1ps

module tb_riscv_if_stage();

    parameter CLK_PERIOD = 10; // 100 MHz clock

    reg         clk;
    reg         nreset;

    // Control Inputs
    reg         stall_if;
    reg         flush_if;
    reg         pc_src_ex;
    reg  [31:0] pc_target_ex;

    // Memory & Pipeline Interconnects
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    wire [31:0] if_id_pc;
    wire [31:0] if_id_pc_plus_4;
    wire [31:0] if_id_instr;

    integer errors = 0;

    // Instantiate Instruction Memory
    instruction_mem #(
        .MEM_DEPTH(64)
    ) u_imem (
        .addr(imem_addr),
        .rdata(imem_rdata)
    );

    // Instantiate UUT
    riscv_if_stage #(
        .RESET_VECTOR(32'h0000_0000)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .stall_if(stall_if),
        .flush_if(flush_if),
        .pc_src_ex(pc_src_ex),
        .pc_target_ex(pc_target_ex),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .if_id_pc(if_id_pc),
        .if_id_pc_plus_4(if_id_pc_plus_4),
        .if_id_instr(if_id_instr)
    );

    // Clock Generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_riscv_if_stage);

        clk          = 0;
        nreset        = 0;
        stall_if     = 0;
        flush_if     = 0;
        pc_src_ex    = 0;
        pc_target_ex = 32'd0;

        #(CLK_PERIOD * 3);
        @(negedge clk);
        nreset = 1;

        $display("\n=======================================================================================================");
        $display("                   DAY 80: RISC-V INSTRUCTION FETCH (IF) STAGE VERIFICATION                            ");
        $display("=======================================================================================================");

        // --- TEST 1: Normal Sequential Fetch (PC + 4 Progression) ---
        $display("\n--- TEST 1: Sequential Instruction Fetching ---");
        @(posedge clk); // Allow pipeline to latch instruction at PC = 0x00
        #(1);
        if (if_id_pc !== 32'h0000_0000 || if_id_instr !== 32'h00500093) begin
            $display("[FAIL] Cycle 1 Mismatch! PC=0x%08h, Instr=0x%08h", if_id_pc, if_id_instr);
            errors = errors + 1;
        end else begin
            $display("[PASS] Cycle 1: PC=0x00, Fetched: 0x%08h", if_id_instr);
        end

        @(posedge clk); // PC = 0x04
        #(1);
        if (if_id_pc !== 32'h0000_0004 || if_id_instr !== 32'h00A00113) begin
            $display("[FAIL] Cycle 2 Mismatch! PC=0x%08h, Instr=0x%08h", if_id_pc, if_id_instr);
            errors = errors + 1;
        end else begin
            $display("[PASS] Cycle 2: PC=0x04, Fetched: 0x%08h", if_id_instr);
        end

        @(posedge clk); // PC = 0x08
        #(1);
        if (if_id_pc !== 32'h0000_0008 || if_id_instr !== 32'h002081B3) begin
            $display("[FAIL] Cycle 3 Mismatch! PC=0x%08h, Instr=0x%08h", if_id_pc, if_id_instr);
            errors = errors + 1;
        end else begin
            $display("[PASS] Cycle 3: PC=0x08, Fetched: 0x%08h", if_id_instr);
        end

        // --- TEST 2: Pipeline Stall Assertion (Load-Use Dependency Emulation) ---
        $display("\n--- TEST 2: Pipeline Stall Verification (Freeze PC and IF/ID) ---");
        @(negedge clk);
        stall_if = 1'b1; // Stall pipeline while fetching PC = 0x0C

        // Hold stall for 2 cycles
        repeat (2) begin
            @(posedge clk);
            #(1);
            if (if_id_pc !== 32'h0000_0008 || if_id_instr !== 32'h002081B3) begin
                $display("[FAIL] Pipeline drifted during stall! PC=0x%08h", if_id_pc);
                errors = errors + 1;
            end
        end
        $display("[PASS] Pipeline correctly held static across 2 stall cycles!");

        @(negedge clk);
        stall_if = 1'b0; // Release stall

        @(posedge clk);
        #(1);
        if (if_id_pc !== 32'h0000_000C || if_id_instr !== 32'h40110233) begin
            $display("[FAIL] Failed to resume fetch after stall! PC=0x%08h", if_id_pc);
            errors = errors + 1;
        end else begin
            $display("[PASS] Pipeline cleanly resumed: PC=0x0C, Fetched: 0x%08h", if_id_instr);
        end

        // --- TEST 3: Branch / Jump Redirection with Flush ---
        $display("\n--- TEST 3: Branch Redirection & Pipeline Flush ---");
        @(negedge clk);
        pc_src_ex    = 1'b1;
        pc_target_ex = 32'h0000_0020; // Jump to target address 0x20
        flush_if     = 1'b1;          // Invalidate instruction currently entering IF/ID

        @(posedge clk);
        #(1);
        // The flushed cycle must present a NOP to the ID stage
        if (if_id_instr !== 32'h0000_0000) begin
            $display("[FAIL] Flush failed to inject NOP bubble! Got: 0x%08h", if_id_instr);
            errors = errors + 1;
        end else begin
            $display("[PASS] Flush cycle: NOP (0x00000000) injected into IF/ID register!");
        end

        @(negedge clk);
        pc_src_ex = 1'b0;
        flush_if  = 1'b0;

        @(posedge clk);
        #(1);
        // Verify target address instruction is captured in IF/ID
        if (if_id_pc !== 32'h0000_0020 || if_id_instr !== 32'h11111113) begin
            $display("[FAIL] Branch target fetch failed! PC=0x%08h, Got: 0x%08h (Expected 0x11111113)",
                     if_id_pc, if_id_instr);
            errors = errors + 1;
        end else begin
            $display("[PASS] Branch target arrived: PC=0x20, Fetched Target Instr: 0x%08h", if_id_instr);
        end

        // --- TEST 4: Flush Priority Over Stall ---
        $display("\n--- TEST 4: Flush Priority Over Stall Conflict ---");
        @(negedge clk);
        stall_if     = 1'b1;
        flush_if     = 1'b1;
        pc_src_ex    = 1'b1;
        pc_target_ex = 32'h0000_0020;

        @(posedge clk);
        #(1);
        if (if_id_instr !== 32'h0000_0000) begin
            $display("[FAIL] Flush did not inject NOP bubble! Got: 0x%08h", if_id_instr);
            errors = errors + 1;
        end else if (imem_addr !== 32'h0000_0020) begin
            $display("[FAIL] PC did not jump to branch target under stall! PC=0x%08h", imem_addr);
            errors = errors + 1;
        end else begin
            $display("[PASS] Flush successfully overrode stall: NOP injected AND PC redirected to 0x20!");
        end

        #(CLK_PERIOD * 5);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 80 RISC-V IF STAGE VERIFICATION SUCCESSFUL");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule