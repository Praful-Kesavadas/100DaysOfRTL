`timescale 1ns / 1ps

module tb_multi_cycle_decoder();

    parameter CLK_PERIOD = 10;

    reg        clk;
    reg        nreset;
    reg  [5:0] opcode;

    wire       pc_write;
    wire       pc_write_cond;
    wire       i_or_d;
    wire       mem_read;
    wire       mem_write;
    wire       ir_write;
    wire       reg_write;
    wire       mem_to_reg;
    wire       alu_src_a;
    wire [1:0] alu_src_b;
    wire [1:0] alu_op;
    wire [1:0] pc_source;
    wire [3:0] current_state;

    integer errors = 0;

    // Instantiate UUT
    multi_cycle_decoder uut (
        .clk(clk),
        .nreset(nreset),
        .opcode(opcode),
        .pc_write(pc_write),
        .pc_write_cond(pc_write_cond),
        .i_or_d(i_or_d),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .ir_write(ir_write),
        .reg_write(reg_write),
        .mem_to_reg(mem_to_reg),
        .alu_src_a(alu_src_a),
        .alu_src_b(alu_src_b),
        .alu_op(alu_op),
        .pc_source(pc_source),
        .current_state(current_state)
    );

    // 100 MHz Clock Generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Check the settled state FIRST, then advance to the next cycle
    task check_step(
        input [3:0]   exp_state,
        input [159:0] state_name
    );
        begin
            if (current_state !== exp_state) begin
                $display("[FAIL] At %5t ns | Expected State: %0d (%-10s) | Got: %0d", 
                         $time, exp_state, state_name, current_state);
                errors = errors + 1;
            end else begin
                $display("[PASS] At %5t ns | State = %2d (%-10s) | IRWr = %b, MemRd = %b, MemWr = %b, RegWr = %b, PCWr = %b", 
                         $time, current_state, state_name, ir_write, mem_read, mem_write, reg_write, pc_write);
            end

            // Step clock to advance FSM to next cycle
            @(posedge clk);
            #1; // Delta delay to settle non-blocking assignments
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk    = 0;
        nreset = 0;
        opcode = 6'b000000;

        // Apply Synchronous Reset
        #(CLK_PERIOD * 2);
        @(posedge clk);
        #1;
        nreset = 1; // FSM initializes into STATE_FETCH (0)

        $display("\n=======================================================================================================");
        $display("                 DAY 68: MULTI-CYCLE INSTRUCTION DECODER VERIFICATION                                  ");
        $display("=======================================================================================================\n");

        // -------------------------------------------------------------
        // TEST 1: R-Type (4 Cycles: FETCH -> DECODE -> EXEC_R -> ALU_WB)
        // -------------------------------------------------------------
        $display("--- TEST 1: R-Type Instruction Execution (4 Cycles) ---");
        opcode = 6'b000000;
        check_step(4'd0, "FETCH");
        check_step(4'd1, "DECODE");
        check_step(4'd6, "EXEC_R");
        check_step(4'd7, "ALU_WB");

        // -------------------------------------------------------------
        // TEST 2: Load Word (5 Cycles: FETCH -> DECODE -> MEM_ADR -> MEM_RD -> MEM_WB)
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Load Word (LW) Instruction Execution (5 Cycles) ---");
        opcode = 6'b100011;
        check_step(4'd0, "FETCH");
        check_step(4'd1, "DECODE");
        check_step(4'd2, "MEM_ADR");
        check_step(4'd3, "MEM_RD");
        check_step(4'd4, "MEM_WB");

        // -------------------------------------------------------------
        // TEST 3: Store Word (4 Cycles: FETCH -> DECODE -> MEM_ADR -> MEM_WR)
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Store Word (SW) Instruction Execution (4 Cycles) ---");
        opcode = 6'b101011;
        check_step(4'd0, "FETCH");
        check_step(4'd1, "DECODE");
        check_step(4'd2, "MEM_ADR");
        check_step(4'd5, "MEM_WR");

        // -------------------------------------------------------------
        // TEST 4: Branch Equal (3 Cycles: FETCH -> DECODE -> BRANCH)
        // -------------------------------------------------------------
        $display("\n--- TEST 4: Branch Equal (BEQ) Instruction Execution (3 Cycles) ---");
        opcode = 6'b000100;
        check_step(4'd0, "FETCH");
        check_step(4'd1, "DECODE");
        check_step(4'd9, "BRANCH");

        // -------------------------------------------------------------
        // TEST 5: Jump (3 Cycles: FETCH -> DECODE -> JUMP)
        // -------------------------------------------------------------
        $display("\n--- TEST 5: Jump (JAL) Instruction Execution (3 Cycles) ---");
        opcode = 6'b000010;
        check_step(4'd0, "FETCH");
        check_step(4'd1, "DECODE");
        check_step(4'd10, "JUMP");

        #(CLK_PERIOD);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   ALL MULTI-CYCLE DECODER STATE SEQUENCES VERIFIED!");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");
        $finish;
    end

endmodule