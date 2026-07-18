`timescale 1ns / 1ps

module tb_booth_multiplier;
    parameter WIDTH = 4;

    reg clk;
    reg nreset;
    reg start;
    reg [WIDTH-1:0] A;
    reg [WIDTH-1:0] B;

    wire [2*WIDTH-1:0] result;
    wire valid;

    // Instantiate Core Under Test
    booth_multiplier #(.WIDTH(WIDTH)) uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .A(A),
        .B(B),
        .result(result),
        .valid(valid)
    );

    // 100MHz Clock Generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Verification Driver Task
    task test_signed_mult(input signed [WIDTH-1:0] multi_A, input signed [WIDTH-1:0] multi_B);
        reg signed [2*WIDTH-1:0] expected_product;
        begin
            @(posedge clk);
            A = multi_A;
            B = multi_B;
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            
            expected_product = multi_A * multi_B;

            @(posedge valid); // Wait for core finish strobe
            #1; // For the signal to settle, so that printing will be accurate
            $display("[TEST] Time = %0d | Inputs: A=%0d, B=%0d | Hardware Product=%0d (Expected=%0d)", 
                     $time, multi_A, multi_B, $signed(result), expected_product);
            #20;
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // System Initialization Reset
        nreset = 1'b0;
        start  = 1'b0;
        A      = 0;
        B      = 0;
        #20;
        nreset = 1'b1;
        #20;

        $display("==================================================");
        $display("RUNNING SIGNED RADIX-2 BOOTH MULTIPLIER TESTS     ");
        $display("==================================================");

        // Test Case 1: Negative * Positive (Your manual example: -6 * 3 = -18)
        test_signed_mult(4'b1010, 4'b0011); 

        // Test Case 2: Positive * Positive (5 * 2 = 10)
        test_signed_mult(4'b0101, 4'b0010);

        // Test Case 3: Negative * Negative (-3 * -2 = 6)
        test_signed_mult(4'b1101, 4'b1110);

        // Test Case 4: Zero Operand Identity (-7 * 0 = 0)
        test_signed_mult(4'b1001, 4'b0000);

        $display("==================================================");
        $finish;
    end
endmodule