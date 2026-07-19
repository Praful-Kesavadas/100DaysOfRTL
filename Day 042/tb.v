`timescale 1ns / 1ps

module tb_restoring_divider;
    parameter WIDTH = 4;

    reg clk;
    reg nreset;
    reg start;
    reg [WIDTH-1:0] dividend;
    reg [WIDTH-1:0] divisor;

    wire [WIDTH-1:0] quotient;
    wire [WIDTH-1:0] remainder;
    wire div_by_zero;
    wire valid;

    // Instantiate Unit Under Test
    restoring_divider #(.WIDTH(WIDTH)) uut (
        .clk(clk), .nreset(nreset), .start(start),
        .dividend(dividend), .divisor(divisor),
        .quotient(quotient), .remainder(remainder),
        .div_by_zero(div_by_zero), .valid(valid)
    );

    // Clock Generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Verification Task
    task test_division(input [WIDTH-1:0] test_num, input [WIDTH-1:0] test_den);
        begin
            @(posedge clk);
            dividend = test_num;
            divisor  = test_den;
            start    = 1'b1;
            @(posedge clk);
            start    = 1'b0;
            
            @(posedge valid); // Handshake catches the data instantly!
            #1;
            $display("[TEST] Inputs: %0d / %0d | Quotient=%0d, Remainder=%0d | DivByZero Status=%b", 
                     test_num, test_den, quotient, remainder, div_by_zero);
            #20;
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        nreset = 1'b0; start = 1'b0; dividend = 0; divisor = 0;
        #20; nreset = 1'b1; #20;

        $display("==================================================");
        $display("RUNNING HARDWARE RESTORING DIVISION ACCELERATOR TESTS");
        $display("==================================================");

        // Case 1: Standard clean division (12 / 4 = 3, Remainder 0)
        test_division(4'd12, 4'd4);

        // Case 2: Division with fractional remainder (your manual example: 11 / 3 = 3, Remainder 2)
        test_division(4'd11, 4'd3);

        // Case 3: Zero dividend bypass evaluation (0 / 5 = 0, Remainder 0)
        test_division(4'd0, 4'd5);

        // Case 4: Critical Divide-by-Zero bypass safety check (8 / 0 -> Max Quotient, DivByZero Flag)
        test_division(4'd8, 4'd0);

        $display("==================================================");
        $finish;
    end
endmodule