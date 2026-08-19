`timescale 1ns / 1ps

module tb_logarithmic_barrel_shifter();

    localparam LSL = 3'b000;
    localparam LSR = 3'b001;
    localparam ASR = 3'b010;
    localparam ROL = 3'b011;
    localparam ROR = 3'b100;

    reg  [15:0]  din;
    reg  [3:0] shift_amt;
    reg  [2:0]  mode;
    wire [15:0]  dout;

    integer errors = 0;

    // Instantiate Barrel Shifter
    logarithmic_barrel_shifter uut (
        .din(din),
        .shift_amt(shift_amt),
        .mode(mode),
        .dout(dout)
    );

    // Modular Verification Task
    task check_shift(
        input [199:0] test_name,
        input [15:0]  in_din,
        input [3:0] in_amt,
        input [2:0] in_mode,
        input [15:0]  exp_dout
    );
        begin
            din       = in_din;
            shift_amt = in_amt;
            mode      = in_mode;
            #10; // Combinational propagation delay

            $display("%-28s | In = 0x%04h | Amt = %2d | Mode = %3b | Dout = 0x%04h (Exp: 0x%04h)", 
                     test_name, in_din, in_amt, in_mode, dout, exp_dout);

            if (dout !== exp_dout) begin
                $display("   --> [FAIL] MISMATCH DETECTED!");
                errors = errors + 1;
            end else begin
                $display("   --> [PASS]");
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        din       = 16'h0000;
        shift_amt = 4'd0;
        mode      = LSL;
        #10;

        $display("\n=========================================================================================");
        $display("          DAY 66: 16-BIT LOGARITHMIC BARREL SHIFTER VERIFICATION                         ");
        $display("=========================================================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Zero Shift / Pass-Through (Amt = 0)
        // -------------------------------------------------------------
        $display("--- TEST 1: Zero Shift (Pass-Through) ---");
        check_shift("LSL: Zero shift", 16'hA5C3, 4'd0, LSL, 16'hA5C3);
        check_shift("LSR: Zero shift", 16'hA5C3, 4'd0, LSR, 16'hA5C3);
        check_shift("ASR: Zero shift", 16'h8001, 4'd0, ASR, 16'h8001);
        check_shift("ROL: Zero shift", 16'h1234, 4'd0, ROL, 16'h1234);
        check_shift("ROR: Zero shift", 16'h1234, 4'd0, ROR, 16'h1234);

        // -------------------------------------------------------------
        // TEST 2: Logical Shift Left (LSL)
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Logical Shift Left (LSL) ---");
        check_shift("LSL: Shift by 1",  16'h0001, 4'd1,  LSL, 16'h0002);
        check_shift("LSL: Shift by 4",  16'h000F, 4'd4,  LSL, 16'h00F0);
        check_shift("LSL: Shift by 8",  16'h00FF, 4'd8,  LSL, 16'hFF00);
        check_shift("LSL: Shift by 12", 16'h000F, 4'd12, LSL, 16'hF000);

        // -------------------------------------------------------------
        // TEST 3: Logical Shift Right (LSR)
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Logical Shift Right (LSR) ---");
        check_shift("LSR: Shift by 1",  16'h8000, 4'd1,  LSR, 16'h4000);
        check_shift("LSR: Shift by 4",  16'hF000, 4'd4,  LSR, 16'h0F00);
        check_shift("LSR: Shift by 8",  16'hFF00, 4'd8,  LSR, 16'h00FF);
        check_shift("LSR: Shift by 15", 16'h8000, 4'd15, LSR, 16'h0001);

        // -------------------------------------------------------------
        // TEST 4: Arithmetic Shift Right (ASR - Sign Extension)
        // -------------------------------------------------------------
        $display("\n--- TEST 4: Arithmetic Shift Right (ASR) ---");
        // Positive input (MSB = 0): Zero extended
        check_shift("ASR (Pos): Shift by 4", 16'h7000, 4'd4, ASR, 16'h0700);
        // Negative input (MSB = 1): Replicates 1s
        check_shift("ASR (Neg): Shift by 1", 16'h8000, 4'd1, ASR, 16'hC000);
        check_shift("ASR (Neg): Shift by 4", 16'h8000, 4'd4, ASR, 16'hF800);
        check_shift("ASR (Neg): Shift by 8", 16'h85A0, 4'd8, ASR, 16'hFF85);
        check_shift("ASR (Neg): Shift by 15",16'h8000, 4'd15,ASR, 16'hFFFF);

        // -------------------------------------------------------------
        // TEST 5: Rotate Left (ROL)
        // -------------------------------------------------------------
        $display("\n--- TEST 5: Rotate Left (ROL) ---");
        check_shift("ROL: Shift by 1",  16'h8001, 4'd1, ROL, 16'h0003);
        check_shift("ROL: Shift by 4",  16'hF000, 4'd4, ROL, 16'h000F);
        check_shift("ROL: Shift by 8",  16'h1234, 4'd8, ROL, 16'h3412);

        // -------------------------------------------------------------
        // TEST 6: Rotate Right (ROR)
        // -------------------------------------------------------------
        $display("\n--- TEST 6: Rotate Right (ROR) ---");
        check_shift("ROR: Shift by 1",  16'h0003, 4'd1, ROR, 16'h8001);
        check_shift("ROR: Shift by 4",  16'h000F, 4'd4, ROR, 16'hF000);
        check_shift("ROR: Shift by 8",  16'h1234, 4'd8, ROR, 16'h3412);

        // -------------------------------------------------------------
        // FINAL SUMMARY
        // -------------------------------------------------------------
        $display("\n=========================================================================================");
        if (errors == 0)
            $display("   ALL 16-BIT LOGARITHMIC BARREL SHIFTER TESTS PASSED SUCCESSFULLY!");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=========================================================================================\n");

        #20;
        $finish;
    end

endmodule