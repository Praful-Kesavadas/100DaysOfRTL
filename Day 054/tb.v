`timescale 1ns / 1ps

module tb_sine_lut();

    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 16;
    parameter ADDR_WIDTH = $clog2(DEPTH);
    parameter CLK_PERIOD = 10;

    reg                  clk;
    reg  [ADDR_WIDTH-1:0] addr;
    wire [DATA_WIDTH-1:0] sine_val;

    integer file_handle;
    integer i;

    // Instantiate UUT
    sine_lut #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .addr(addr),
        .sine_val(sine_val)
    );

    // Clock Generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        clk  = 0;
        addr = 0;

        // Open output log file for writing
        file_handle = $fopen("sim_output.hex", "w");
        if (file_handle == 0) begin
            $display("[ERROR] Failed to create output file 'sim_output.hex'!");
            $finish;
        end

        #(CLK_PERIOD * 2);

        $display("Starting Sine Wave ROM Sweep... Output dumping to sim_output.hex");

        // Sweep 2 complete phase cycles (32 samples)
        for (i = 0; i < 32; i = i + 1) begin
            @(negedge clk);
            addr = i[ADDR_WIDTH-1:0];

            @(posedge clk); #1;
            // Write formatted hex output directly to file
            $fdisplay(file_handle, "%02X", sine_val);
        end

        $fclose(file_handle);
        $display("Simulation complete! File 'sim_output.hex' closed successfully.");
        $finish;
    end

endmodule