`timescale 1ns / 1ps

module tb_code_converter;

    reg [3:0] data_in;
    reg mode;
    wire [3:0] converted;

    // Workaround tracking net for safe iverilog $monitor tracking
    wire [87:0] mode_str = mode ? "GRAY_TO_BIN" : "BIN_TO_GRAY";

    // Instantiate the Device Under Test (DUT)
    code_converter uut (
        .data_in(data_in),
        .mode(mode),
        .converted(converted)
    );

    // Automated Console Logger
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
        $monitor("Time = %0d ns | Mode = %s | Input_Bus = %b (Dec:%2d) | Output_Bus = %b (Dec:%2d)", 
                 $time, mode_str, data_in, data_in, converted, converted);
    end

    integer i;

    initial begin
        // --- State Initialization at Time Zero ---
        data_in = 4'b0000; mode = 1'b0; #10;
        
        // =================================================================
        // PHASE 1: BINARY TO GRAY SWEEP (mode = 0)
        // =================================================================
        $display("--- Starting Binary to Gray Conversion Verification ---");
        for (i = 0; i < 16; i = i + 1) begin
            data_in = i;
            #10;
        end
        data_in = 0;
        // =================================================================
        // PHASE 2: GRAY TO BINARY SWEEP (mode = 1)
        // =================================================================
        $display("--- Starting Gray to Binary Conversion Verification ---");
        mode = 1'b1;
        #10;
        
        for (i = 1; i < 16; i = i + 1) begin
            data_in = i;
            #10;
        end

        // --- Return to Idle State ---
        mode = 1'b0; data_in = 4'b0000; #10;
        
        $display("--- Day 15 Bidirectional Code Converter Verification Complete ---");
        $finish;
    end

endmodule