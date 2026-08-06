`timescale 1ns / 1ps

module tb_alu();

    parameter DATA_WIDTH = 16;
    parameter CLK_PERIOD = 10;

    reg                  clk;
    reg                  nreset;
    reg  [3:0]           alu_op;
    reg  [DATA_WIDTH-1:0] A, B;
    wire                 zero, negative, carry, overflow;
    wire [DATA_WIDTH-1:0] result;

    integer errors = 0;

    // Instantiate ALU
    alu #(
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .alu_op(alu_op),
        .A(A),
        .B(B),
        .zero(zero),
        .negative(negative),
        .carry(carry),
        .overflow(overflow),
        .result(result)
    );

    // 100 MHz Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk    = 0;
        nreset = 0;
        alu_op = 0;
        A      = 0;
        B      = 0;

        // Apply Reset
        #(CLK_PERIOD * 2);
        nreset = 1;
        #(CLK_PERIOD);

        $display("\n====================================================");
        $display("   DAY 58: FULL 16-OPERATION ALU CORE VERIFICATION");
        $display("====================================================\n");

        // -------------------------------------------------------------
        // GROUP 1: ARITHMETIC OPERATIONS (Opcodes 0 to 3)
        // -------------------------------------------------------------
        $display("--- Group 1: Arithmetic Operations ---");

        // Op 0: ADD (50 + 25 = 75)
        @(negedge clk); alu_op = 4'd0; A = 16'd50; B = 16'd25;
        @(posedge clk); #1;
        if (result === 16'd75 && !zero && !negative && !carry && !overflow)
            $display("[PASS] Op  0 (ADD) :  50 + 25 = %0d", result);
        else begin $display("[FAIL] Op 0 (ADD) Mismatch!"); errors = errors + 1; end

        // Op 1: SUB (100 - 100 = 0) -> Tests Zero Flag (Z)
        @(negedge clk); alu_op = 4'd1; A = 16'd100; B = 16'd100;
        @(posedge clk); #1;
        if (result === 16'd0 && zero)
            $display("[PASS] Op  1 (SUB) : 100 - 100 = %0d (Zero Flag Z=1 Asserted)", result);
        else begin $display("[FAIL] Op 1 (SUB) Mismatch!"); errors = errors + 1; end

        // Op 2: INC (15 + 1 = 16)
        @(negedge clk); alu_op = 4'd2; A = 16'h000F; B = 16'h1234; // B should be ignored
        @(posedge clk); #1;
        if (result === 16'h0010)
            $display("[PASS] Op  2 (INC) : 0x000F + 1 = 0x%04h", result);
        else begin $display("[FAIL] Op 2 (INC) Mismatch!"); errors = errors + 1; end

        // Op 3: DEC (0 - 1 = 0xFFFF / -1) -> Tests Negative Flag (N)
        @(negedge clk); alu_op = 4'd3; A = 16'h0000; B = 16'h1234;
        @(posedge clk); #1;
        if (result === 16'hFFFF && negative)
            $display("[PASS] Op  3 (DEC) : 0x0000 - 1 = 0x%04h (Negative Flag N=1)", result);
        else begin $display("[FAIL] Op 3 (DEC) Mismatch!"); errors = errors + 1; end

        // Extra Arithmetic Check: Signed Overflow Flag (V=1)
        @(negedge clk); alu_op = 4'd0; A = 16'h7FFF; B = 16'h0001; // +32767 + 1 = -32768
        @(posedge clk); #1;
        if (result === 16'h8000 && overflow && negative)
            $display("[PASS] Edge Case    : 0x7FFF + 1 = 0x%04h (Signed Overflow V=1, N=1)", result);
        else begin $display("[FAIL] Signed Overflow Check Failed!"); errors = errors + 1; end

        // -------------------------------------------------------------
        // GROUP 2: BITWISE LOGIC OPERATIONS (Opcodes 4 to 9)
        // -------------------------------------------------------------
        $display("\n--- Group 2: Bitwise Logic Operations ---");

        // Op 4: AND
        @(negedge clk); alu_op = 4'd4; A = 16'hFF00; B = 16'h0F0F;
        @(posedge clk); #1;
        if (result === 16'h0F00)
            $display("[PASS] Op  4 (AND) : 0xFF00 & 0x0F0F = 0x%04h", result);
        else begin $display("[FAIL] Op 4 (AND) Mismatch!"); errors = errors + 1; end

        // Op 5: OR
        @(negedge clk); alu_op = 4'd5; A = 16'hFF00; B = 16'h00FF;
        @(posedge clk); #1;
        if (result === 16'hFFFF)
            $display("[PASS] Op  5 (OR)  : 0xFF00 | 0x00FF = 0x%04h", result);
        else begin $display("[FAIL] Op 5 (OR) Mismatch!"); errors = errors + 1; end

        // Op 6: XOR
        @(negedge clk); alu_op = 4'd6; A = 16'hAAAA; B = 16'h5555;
        @(posedge clk); #1;
        if (result === 16'hFFFF)
            $display("[PASS] Op  6 (XOR) : 0xAAAA ^ 0x5555 = 0x%04h", result);
        else begin $display("[FAIL] Op 6 (XOR) Mismatch!"); errors = errors + 1; end

        // Op 7: NOT
        @(negedge clk); alu_op = 4'd7; A = 16'h1234; B = 16'h0000;
        @(posedge clk); #1;
        if (result === 16'hEDCB)
            $display("[PASS] Op  7 (NOT) : ~0x1234 = 0x%04h", result);
        else begin $display("[FAIL] Op 7 (NOT) Mismatch!"); errors = errors + 1; end

        // Op 8: NAND
        @(negedge clk); alu_op = 4'd8; A = 16'hFFFF; B = 16'hF000;
        @(posedge clk); #1;
        if (result === 16'h0FFF)
            $display("[PASS] Op  8 (NAND): ~(0xFFFF & 0xF000) = 0x%04h", result);
        else begin $display("[FAIL] Op 8 (NAND) Mismatch!"); errors = errors + 1; end

        // Op 9: NOR
        @(negedge clk); alu_op = 4'd9; A = 16'h00FF; B = 16'h0000;
        @(posedge clk); #1;
        if (result === 16'hFF00)
            $display("[PASS] Op  9 (NOR) : ~(0x00FF | 0x0000) = 0x%04h", result);
        else begin $display("[FAIL] Op 9 (NOR) Mismatch!"); errors = errors + 1; end

        // -------------------------------------------------------------
        // GROUP 3: SHIFT & ROTATE OPERATIONS (Opcodes 10 to 14)
        // -------------------------------------------------------------
        $display("\n--- Group 3: Shift & Rotate Operations ---");

        // Op 10: SLL (Logical Shift Left)
        @(negedge clk); alu_op = 4'd10; A = 16'h0001; B = 16'd8;
        @(posedge clk); #1;
        if (result === 16'h0100)
            $display("[PASS] Op 10 (SLL) : 0x0001 << 8 = 0x%04h", result);
        else begin $display("[FAIL] Op 10 (SLL) Mismatch!"); errors = errors + 1; end

        // Op 11: SRL (Logical Shift Right)
        @(negedge clk); alu_op = 4'd11; A = 16'h8000; B = 16'd4;
        @(posedge clk); #1;
        if (result === 16'h0800)
            $display("[PASS] Op 11 (SRL) : 0x8000 >> 4 = 0x%04h", result);
        else begin $display("[FAIL] Op 11 (SRL) Mismatch!"); errors = errors + 1; end

        // Op 12: SRA (Arithmetic Shift Right - Sign Extended)
        @(negedge clk); alu_op = 4'd12; A = 16'h8000; B = 16'd4; // -32768 >>> 4 = -2048 (0xF800)
        @(posedge clk); #1;
        if (result === 16'hF800 && negative)
            $display("[PASS] Op 12 (SRA) : 0x8000 >>> 4 = 0x%04h (Sign preserved N=1)", result);
        else begin $display("[FAIL] Op 12 (SRA) Mismatch! Got 0x%04h", result); errors = errors + 1; end

        // Op 13: ROL (Rotate Left)
        @(negedge clk); alu_op = 4'd13; A = 16'hC001; B = 16'd2; // 1100_0000_0000_0001 << 2 rot -> 0000_0000_0000_0111 (0x0007)
        @(posedge clk); #1;
        if (result === 16'h0007)
            $display("[PASS] Op 13 (ROL) : Rotate Left 0xC001 by 2 = 0x%04h", result);
        else begin $display("[FAIL] Op 13 (ROL) Mismatch! Got 0x%04h", result); errors = errors + 1; end

        // Op 14: ROR (Rotate Right)
        @(negedge clk); alu_op = 4'd14; A = 16'h0003; B = 16'd2; // 0000_0000_0000_0011 >> 2 rot -> 1100_0000_0000_0000 (0xC000)
        @(posedge clk); #1;
        if (result === 16'hC000 && negative)
            $display("[PASS] Op 14 (ROR) : Rotate Right 0x0003 by 2 = 0x%04h", result);
        else begin $display("[FAIL] Op 14 (ROR) Mismatch! Got 0x%04h", result); errors = errors + 1; end

        // -------------------------------------------------------------
        // GROUP 4: PASS-THROUGH (Opcode 15)
        // -------------------------------------------------------------
        $display("\n--- Group 4: Pass-Through Operation ---");

        // Op 15: PASS
        @(negedge clk); alu_op = 4'd15; A = 16'hA5A5; B = 16'h1234;
        @(posedge clk); #1;
        if (result === 16'hA5A5)
            $display("[PASS] Op 15 (PASS): Output = 0x%04h (Operand A passed unchanged)", result);
        else begin $display("[FAIL] Op 15 (PASS) Mismatch!"); errors = errors + 1; end

        // SUMMARY
        $display("\n====================================================");
        if (errors == 0) $display(" ALL 16 ALU CORE OPERATIONS PASSED SUCCESSFULLY!");
        else             $display(" VERIFICATION FAILED WITH %0d ERROR(S)", errors);
        $display("====================================================\n");

        $finish;
    end

endmodule