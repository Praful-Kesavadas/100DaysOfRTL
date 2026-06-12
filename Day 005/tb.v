module tb_priorityenc8to3();
    reg [7:0] in;
    wire [2:0] out;
    wire valid;

    priorityenc8to3 uut(.out(out), .valid(valid), .in(in));

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
    end

    initial begin
        #10 in = 8'd1;
        #10 in = 8'd3;
        #10 in = 8'd4;
        #10 in = 8'd0;
        #10 in = 8'd10;
        #10 in = 8'b10010011;
        #10 in = 8'b00100100;
        #10 in = 8'b01000010;
        #10 $finish;
    end

endmodule