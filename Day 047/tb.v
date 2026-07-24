`timescale 1ns / 1ps

module tb_double_dabble();

    localparam WIDTH = 8;

    reg              clk;
    reg              nreset;
    reg              start;
    reg  [WIDTH-1:0] data_in;

    wire [3:0]       hundreds;
    wire [3:0]       tens;
    wire [3:0]       ones;
    wire             valid;
    wire             carry;

    integer error_count = 0;

    // Instantiate UUT
    double_dabble_converter #(
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .start(start),
        .data_in(data_in),
        .hundreds(hundreds),
        .tens(tens),
        .ones(ones),
        .valid(valid),
        .carry(carry)
    );

    // 100 MHz Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Task to run conversion and check result
    task check_conversion;
        input [WIDTH-1:0] test_val;
        input [3:0]       exp_h, exp_t, exp_o;
        begin
            $display("\n--- Testing Binary Input: %0d (8'b%b) ---", test_val, test_val);
            @(negedge clk);
            data_in = test_val;
            start   = 1'b1;
            
            @(negedge clk);
            start   = 1'b0;

            // Wait for completion pulse
            while (!valid) @(posedge clk);

            if ({hundreds, tens, ones} === {exp_h, exp_t, exp_o}) begin
                $display("--> PASS: BCD Output = %0d%0d%0d (Hex: 12'h%h%h%h)", 
                         hundreds, tens, ones, hundreds, tens, ones);
            end else begin
                $display("--> FAIL: Got BCD = %0d%0d%0d | Expected = %0d%0d%0d", 
                         hundreds, tens, ones, exp_h, exp_t, exp_o);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
        
        nreset  = 0;
        start   = 0;
        data_in = 0;
        #20;
        nreset  = 1;
        #10;

        // Test Cases
        check_conversion(8'd243, 4'd2, 4'd4, 4'd3); // Manual trace example
        check_conversion(8'd255, 4'd2, 4'd5, 4'd5); // Maximum 8-bit value
        check_conversion(8'd0,   4'd0, 4'd0, 4'd0); // Zero boundary
        check_conversion(8'd99,  4'd0, 4'd9, 4'd9); // 2-digit boundary
        check_conversion(8'd100, 4'd1, 4'd0, 4'd0); // 3-digit boundary

        $display("\n==================================================");
        if (error_count == 0) $display(" ALL DOUBLE DABBLE TESTS PASSED!");
        else                  $display(" TESTBENCH FAILED (%0d errors)", error_count);
        $display("==================================================\n");

        $finish;
    end

endmodule