`timescale 1ns / 1ps

module tb_seq_detector;

    reg clk;
    reg nreset;
    reg in;
    wire detected;

    // Instantiate Moore UUT
    seq_detector_overlapping uut (
        .clk(clk),
        .nreset(nreset),
        .in(in),
        .detected(detected)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task push_bit(input b);
        begin
            @(posedge clk);
            #1; // Minor hold-time delay for clean wave rendering
            in = b;
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // --- Step 1: Master Clear Initialization ---
        nreset = 1'b0; in = 1'b0; #15;
        nreset = 1'b1; #5;

        // --- Step 2: Inject First Clean Sequence (1011) ---
        // Input Stream: 1 -> 0 -> 1 -> 1
        push_bit(1'b1);
        push_bit(1'b0);
        push_bit(1'b1);
        push_bit(1'b1); // 'detected' should rise after the next edge

        // --- Step 3: Inject Non-Matching Padding Bits ---
        push_bit(1'b0);
        push_bit(1'b0);

        // --- Step 4: Verify Overlapping Digits (1011011) ---
        // First match:  [1 0 1 1]
        // Second match:     1 0 [1 1] -> The '11' bridges them!
        push_bit(1'b1); // Start 1st
        push_bit(1'b0);
        push_bit(1'b1);
        push_bit(1'b1); // Complete 1st match
        push_bit(1'b0); // Overlap starts...
        push_bit(1'b1);
        push_bit(1'b1); // Complete 2nd match via overlapping reuse

        push_bit(1'b0);
        #50;
        $finish;
    end

endmodule