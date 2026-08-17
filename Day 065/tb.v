`timescale 1ns / 1ps

module tb_mac_pipelined();

    parameter CLK_PERIOD = 10;
    parameter DATA_WIDTH = 16;
    parameter ACC_WIDTH  = 40;

    localparam CLR_LOAD = 2'b00;
    localparam MAC_ADD  = 2'b01;
    localparam MAC_SUB  = 2'b10;
    localparam PREADD_C = 2'b11;

    reg                             clk;
    reg                             nreset;
    reg                             start;
    reg  signed [DATA_WIDTH-1:0]    A, B;
    reg  signed [ACC_WIDTH-1:0]     C;
    reg         [1:0]               op_code;

    wire signed [ACC_WIDTH-1:0]     product;
    wire                            valid_out;
    wire                            overflow;

    integer errors = 0;

    mac_pipelined #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .A(A),
        .B(B),
        .C(C),
        .op_code(op_code),
        .product(product),
        .valid_out(valid_out),
        .overflow(overflow)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    // Single-operation synchronous driver & checker
    task run_single_op(
        input [199:0]                test_name,
        input [1:0]                  in_op,
        input signed [DATA_WIDTH-1:0] in_a, in_b,
        input signed [ACC_WIDTH-1:0]  in_c,
        input signed [ACC_WIDTH-1:0]  exp_product,
        input                        exp_overflow
    );
        begin
            @(negedge clk);
            start   = 1;
            op_code = in_op;
            A       = in_a;
            B       = in_b;
            C       = in_c;
            
            @(negedge clk);
            start   = 0;

            // Wait 2 pipeline cycles for valid_out to assert
            @(posedge valid_out);
            #1; // Sample immediately after edge

            $display("[T = %6.0f ns] %-34s | Product = %14d (Exp: %14d) | Ovf = %b (Exp: %b)", 
                     $time, test_name, product, exp_product, overflow, exp_overflow);

            if (product !== exp_product || overflow !== exp_overflow) begin
                $display("   --> [FAIL] MISMATCH DETECTED!");
                errors = errors + 1;
            end else begin
                $display("   --> [PASS]");
            end
            @(negedge clk);
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        clk     = 0;
        nreset  = 0;
        start   = 0;
        A       = 0;
        B       = 0;
        C       = 0;
        op_code = CLR_LOAD;

        #(CLK_PERIOD * 2);
        nreset = 1;
        #(CLK_PERIOD);

        $display("\n=========================================================================================");
        $display("          DAY 65: PIPELINED MULTIPLY-ACCUMULATE (MAC) DSP CORE VERIFICATION              ");
        $display("=========================================================================================\n");

        // TEST 1: Clear & Load
        $display("--- TEST 1: CLR_LOAD (Clear & Load Initial Products) ---");
        run_single_op("CLR_LOAD: 25 * 4",   CLR_LOAD, 25,   4,  0,  40'sd100,  1'b0);
        run_single_op("CLR_LOAD: -15 * 20", CLR_LOAD, -15, 20,  0, -40'sd300, 1'b0);

        // TEST 2: Continuous Streaming MAC Sequence (Zero Bubble Pipeline)
        $display("\n--- TEST 2: Continuous Streaming MAC Sequence (Dot-Product) ---");
        fork
            // Thread A: Non-blocking stimulus generator
            begin
                @(negedge clk);
                start = 1; op_code = CLR_LOAD; A = 10; B = 5;  // Step 1: 50
                @(negedge clk);
                start = 1; op_code = MAC_ADD;  A = 20; B = 3;  // Step 2: 50 + 60 = 110
                @(negedge clk);
                start = 1; op_code = MAC_ADD;  A = -5; B = 10; // Step 3: 110 - 50 = 60
                @(negedge clk);
                start = 1; op_code = MAC_ADD;  A = 8;  B = -2; // Step 4: 60 - 16 = 44
                @(negedge clk);
                start = 0;
            end

            // Thread B: Synchronous pipeline monitor
            begin
                @(posedge valid_out); #1;
                $display("[T = %6.0f ns] Stream Step 1: CLR_LOAD (10*5)   | Product = %14d (Exp: %14d) | Ovf = %b", $time, product, 40'sd50, overflow);
                if (product !== 40'sd50) begin errors = errors + 1; $display("   --> [FAIL]"); end else $display("   --> [PASS]");

                @(posedge clk); #1;
                $display("[T = %6.0f ns] Stream Step 2: MAC_ADD  (+20*3)  | Product = %14d (Exp: %14d) | Ovf = %b", $time, product, 40'sd110, overflow);
                if (product !== 40'sd110) begin errors = errors + 1; $display("   --> [FAIL]"); end else $display("   --> [PASS]");

                @(posedge clk); #1;
                $display("[T = %6.0f ns] Stream Step 3: MAC_ADD  (+-5*10) | Product = %14d (Exp: %14d) | Ovf = %b", $time, product, 40'sd60, overflow);
                if (product !== 40'sd60) begin errors = errors + 1; $display("   --> [FAIL]"); end else $display("   --> [PASS]");

                @(posedge clk); #1;
                $display("[T = %6.0f ns] Stream Step 4: MAC_ADD  (+8*-2)  | Product = %14d (Exp: %14d) | Ovf = %b", $time, product, 40'sd44, overflow);
                if (product !== 40'sd44) begin errors = errors + 1; $display("   --> [FAIL]"); end else $display("   --> [PASS]");
            end
        join

        // TEST 3: Multiply-Subtract from Accumulator
        $display("\n--- TEST 3: Multiply-Subtract (MAC_SUB) ---");
        run_single_op("MAC_SUB: 44 - (12*3)", MAC_SUB, 12, 3, 0, 40'sd8, 1'b0);

        // TEST 4: Multiply-Add Pre-Adder Input C
        $display("\n--- TEST 4: Multiply-Add Addend C (PREADD_C) ---");
        run_single_op("PREADD_C: (10*10) + 500", PREADD_C,  10, 10, 500, 40'sd600, 1'b0);
        run_single_op("PREADD_C: (-20*5) + 150", PREADD_C, -20,  5, 150,  40'sd50, 1'b0);

        // TEST 5: Positive Accumulation Overflow
        $display("\n--- TEST 5: Positive Overflow Detection ---");
        run_single_op("Load near +MAX positive", PREADD_C, 0, 0, 40'sh7F_FFFF_FF00, 40'sh7F_FFFF_FF00, 1'b0);
        run_single_op("MAC_ADD Overflow Trigger", MAC_ADD, 3000, 3000, 0, 40'sh7F_FFFF_FF00 + (3000*3000), 1'b1);

        // TEST 6: Negative Subtraction Underflow/Overflow
        $display("\n--- TEST 6: Negative Underflow/Overflow Detection ---");
        run_single_op("Load near -MIN negative", PREADD_C, 0, 0, -40'sh7F_FFFF_FF00, -40'sh7F_FFFF_FF00, 1'b0);
        run_single_op("MAC_SUB Underflow Trigger", MAC_SUB, 3000, 3000, 0, -40'sh7F_FFFF_FF00 - (3000*3000), 1'b1);

        // FINAL SUMMARY
        $display("\n=========================================================================================");
        if (errors == 0)
            $display("   ALL PIPELINED MAC DSP CORE TESTS PASSED SUCCESSFULLY!");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=========================================================================================\n");

        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule