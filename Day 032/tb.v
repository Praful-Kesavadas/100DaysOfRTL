`timescale 1ns / 1ps

module tb_seq_detector_nonoverlapping;

    reg clk;
    reg nreset;
    reg in;
    wire detected;

    seq_detector_nonoverlapping uut (
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
            #1; // Hold-time offset for waveform clarity
            in = b;
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        nreset = 1'b0; in = 1'b0; #15;
        nreset = 1'b1; #5;

        // --- Test Stream: 1011011 ---
        // Yesterday's Moore machine caught TWO matches here.
        // This Non-Overlapping Mealy machine must only catch ONE!
        push_bit(1'b1); // S0 -> S1
        push_bit(1'b0); // S1 -> S2
        push_bit(1'b1); // S2 -> S3
        push_bit(1'b1); // S3 with in=1 -> 'detected' flashes high INSTANTLY!
        
        push_bit(1'b0); // History was flushed; FSM is back at S0
        push_bit(1'b1); 
        push_bit(1'b1); 

        push_bit(1'b0);
        #40;
        $finish;
    end

endmodule