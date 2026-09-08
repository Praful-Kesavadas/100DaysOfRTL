`timescale 1ns / 1ps

module tb_lifo_stack();

    parameter DATA_WIDTH = 16;
    parameter DEPTH      = 8;
    parameter PTR_WIDTH  = 3;
    parameter CLK_PERIOD = 10;

    reg                   clk;
    reg                   nreset;
    reg                   push;
    reg                   pop;
    reg  [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;
    wire                  empty;
    wire                  full;
    wire                  overflow;
    wire                  underflow;

    integer errors = 0;

    // Instantiate Unit Under Test (UUT)
    lifo_stack #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .PTR_WIDTH(PTR_WIDTH)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .push(push),
        .pop(pop),
        .d_in(data_in),
        .d_out(data_out),
        .empty(empty),
        .full(full),
        .overflow(overflow),
        .underflow(underflow)
    );

    // 100 MHz Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Helper task to push a single entry
    task stack_push(input [DATA_WIDTH-1:0] din);
        begin
            @(negedge clk);
            push    = 1'b1;
            pop     = 1'b0;
            data_in = din;
            @(posedge clk);
            #1; // Delta delay after clock edge
            push    = 1'b0;
        end
    endtask

    // Helper task to pop a single entry
    task stack_pop(input [DATA_WIDTH-1:0] exp_dout);
        begin
            @(negedge clk);
            pop  = 1'b1;
            push = 1'b0;
            @(posedge clk);
            #1;
            pop  = 1'b0;
            if (data_out !== exp_dout) begin
                $display("[FAIL] Pop Mismatch! Expected: 0x%04h | Got: 0x%04h", exp_dout, data_out);
                errors = errors + 1;
            end else begin
                $display("[PASS] Popped TOS: 0x%04h (Count: %0d)", data_out, uut.count);
            end
        end
    endtask

    integer j;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_lifo_stack);

        clk     = 0;
        nreset  = 0;
        push    = 0;
        pop     = 0;
        data_in = 0;

        // Apply Reset
        #(CLK_PERIOD * 2);
        @(negedge clk);
        nreset = 1;
        #1;

        $display("\n=======================================================================================================");
        $display("                         DAY 69: HARDWARE LIFO STACK CORE VERIFICATION                                 ");
        $display("=======================================================================================================\n");

        // -------------------------------------------------------------
        // TEST 1: Check Reset State
        // -------------------------------------------------------------
        if (empty !== 1'b1 || full !== 1'b0) begin
            $display("[FAIL] Initial state invalid! empty=%b, full=%b", empty, full);
            errors = errors + 1;
        end else begin
            $display("[PASS] Initial Reset: Stack correctly reports EMPTY (Count: 0)");
        end

        // -------------------------------------------------------------
        // TEST 2: Fill Stack to Maximum Depth (8 items)
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Pushing 8 elements (0x100 to 0x107) ---");
        for (j = 0; j < DEPTH; j = j + 1) begin
            stack_push(16'h0100 + j);
            $display("   Pushed: 0x%04h | Count = %0d | Full = %b", 16'h0100 + j, uut.count, full);
        end

        if (full !== 1'b1) begin
            $display("[FAIL] Stack failed to assert FULL at maximum capacity!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Stack reached maximum capacity: FULL asserted correctly.");
        end

        // -------------------------------------------------------------
        // TEST 3: Overflow Exception Generation
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Stressing Overflow Boundary on Full Stack ---");
        stack_push(16'hDEAD);
        if (overflow !== 1'b1) begin
            $display("[FAIL] Overflow flag failed to assert on invalid push!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Invalid push rejected: OVERFLOW correctly asserted (Count: %0d)", uut.count);
        end

        // -------------------------------------------------------------
        // TEST 4: Simultaneous Push & Pop on Full Stack (In-Place Swap)
        // -------------------------------------------------------------
        $display("\n--- TEST 4: Simultaneous Push & Pop on FULL Stack (Swap 0x0107 with 0xCAFE) ---");
        @(negedge clk);
        push    = 1'b1;
        pop     = 1'b1;
        data_in = 16'hCAFE;
        @(posedge clk);
        #1;
        push = 1'b0;
        pop  = 1'b0;

        if (data_out !== 16'h0107 || overflow !== 1'b0 || full !== 1'b1) begin
            $display("[FAIL] Swap on full failed! DataOut = 0x%04h (Exp: 0x0107), Overflow = %b", data_out, overflow);
            errors = errors + 1;
        end else begin
            $display("[PASS] Swap Succeeded: Popped old TOS 0x%04h, replaced with 0xCAFE, Overflow = 0", data_out);
        end

        // -------------------------------------------------------------
        // TEST 5: Drain Stack and Validate Reverse LIFO Ordering
        // -------------------------------------------------------------
        $display("\n--- TEST 5: Popping All Elements (Verifying LIFO Order) ---");
        // TOS is now 0xCAFE, followed by 0x0106 down to 0x0100
        stack_pop(16'hCAFE);
        for (j = DEPTH - 2; j >= 0; j = j - 1) begin
            stack_pop(16'h0100 + j);
        end

        if (empty !== 1'b1) begin
            $display("[FAIL] Stack failed to assert EMPTY after draining!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Stack drained completely: EMPTY asserted correctly.");
        end

        // -------------------------------------------------------------
        // TEST 6: Underflow Exception Generation
        // -------------------------------------------------------------
        $display("\n--- TEST 6: Stressing Underflow Boundary on Empty Stack ---");
        @(negedge clk);
        pop = 1'b1;
        @(posedge clk);
        #1;
        pop = 1'b0;

        if (underflow !== 1'b1) begin
            $display("[FAIL] Underflow flag failed to assert on invalid pop!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Invalid pop rejected: UNDERFLOW correctly asserted.");
        end

        // Final Audit
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 69 LIFO STACK VERIFICATION SUCCESSFUL");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule