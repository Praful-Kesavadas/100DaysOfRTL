`timescale 1ns / 1ps

module tb_cpu_datapath_layout();

    parameter DATA_WIDTH = 16;
    parameter ADDR_WIDTH = 8;
    parameter CLK_PERIOD = 10;

    reg                   clk;
    reg                   nreset;
    wire [ADDR_WIDTH-1:0] pc_out;
    wire [DATA_WIDTH-1:0] alu_result_out;

    integer errors = 0;

    // Instantiate UUT
    cpu_datapath_layout #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .pc_out(pc_out),
        .alu_result_out(alu_result_out)
    );

    // 100 MHz Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Sample at mid-cycle (negedge clk) where combinational datapath is stable
    task check_instruction(
        input [ADDR_WIDTH-1:0]        exp_pc,
        input [159:0]                 inst_desc,
        input signed [DATA_WIDTH-1:0] exp_alu_out
    );
        reg match;
        begin
            match = (alu_result_out === exp_alu_out) && (pc_out === exp_pc);

            $display("[T = %5t ns] PC = %2d | Inst = 0x%04h | %-24s | ALU Out = %5d (Exp: %5d) | %s", 
                     $time, pc_out, uut.instruction, inst_desc, alu_result_out, exp_alu_out,
                     match ? "PASS" : "FAIL");

            if (!match) begin
                $display("   --> [ERROR] Mismatch on PC = %0d! Expected ALU: %0d, Got: %0d", exp_pc, exp_alu_out, alu_result_out);
                errors = errors + 1;
            end
            @(negedge clk); // Advance to the next cycle's settled state
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk    = 0;
        nreset = 0;

        // Apply Reset
        #(CLK_PERIOD * 2);
        @(negedge clk);
        nreset = 1; #1; // PC is now 0 and combinational logic for PC=0 is settled

        $display("\n=======================================================================================================");
        $display("                   DAY 67: SINGLE-CYCLE CPU DATAPATH EXECUTION VERIFICATION                            ");
        $display("=======================================================================================================\n");

        // Step 0: PC = 0 -> Inst: 0x0100 (ADD R1, R0, R0 -> 10 + 10 = 20)
        check_instruction(8'd0, "ADD R1, R0, R0", 16'd20);

        // Step 1: PC = 1 -> Inst: 0x0211 (ADD R2, R1, R1 -> 20 + 20 = 40)
        check_instruction(8'd1, "ADD R2, R1, R1", 16'd40);

        // Step 2: PC = 2 -> Inst: 0x2312 (AND R3, R1, R2 -> 20 & 40 = 0)
        check_instruction(8'd2, "AND R3, R1, R2", 16'd0);

        // Step 3: PC = 3 -> Inst: 0x3423 (OR  R4, R2, R3 -> 40 | 0 = 40)
        check_instruction(8'd3, "OR  R4, R2, R3", 16'd40);

        // Step 4: PC = 4 -> Inst: 0x4523 (XOR R5, R2, R3 -> 40 ^ 0 = 40)
        check_instruction(8'd4, "XOR R5, R2, R3", 16'd40);

        // Step 5: PC = 5 -> Inst: 0x5640 (SLL R6, R4, 1  -> 40 << 1 = 80)
        check_instruction(8'd5, "SLL R6, R4, 1",  16'd80);

        // Step 6: PC = 6 -> Inst: 0x0000 (ADD R0, R0, R0 -> 10 + 10 = 20)
        check_instruction(8'd6, "ADD R0, R0, R0", 16'd20);

        // Step 7: PC = 7 -> Inst: 0x0000 (ADD R0, R0, R0 -> 20 + 20 = 40)
        check_instruction(8'd7, "ADD R0, R0, R0", 16'd40);

        #(CLK_PERIOD);
        $display("\n-------------------------------- FINAL REGISTER AUDIT --------------------------------");
        $display("R0 = %2d (Exp: 40) | R1 = %2d (Exp: 20) | R2 = %2d (Exp: 40) | R3 = %2d (Exp:  0)", 
                 uut.reg_file[0], uut.reg_file[1], uut.reg_file[2], uut.reg_file[3]);
        $display("R4 = %2d (Exp: 40) | R5 = %2d (Exp: 40) | R6 = %2d (Exp: 80)", 
                 uut.reg_file[4], uut.reg_file[5], uut.reg_file[6]);

        $display("\n=======================================================================================================");
        if (errors == 0 && uut.reg_file[6] == 80 && uut.reg_file[2] == 40)
            $display("   ALL INSTRUCTIONS EXECUTED & VERIFIED!");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule