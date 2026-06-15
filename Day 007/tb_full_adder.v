module tb_full_adder();
    reg a, b, carry_in;
    wire sum, carry_out;

    full_adder uut(.a(a), .b(b), .carry_in(carry_in), .sum(sum), .carry_out(carry_out));

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
        $monitor("Time = %0d ns | Inputs: A = %b B = %b Cin = %b | Outputs: Sum = %b Cout = %b", $time, a, b, carry_in, sum, carry_out);
    end

    initial begin
        a = 0; b = 0; carry_in = 0;
        #10 carry_in = 1;
        #10 carry_in = 0; b = 1;
        #10 b = 0; a = 1;
        #10 a = 0; b = 1; carry_in = 1; 
        #10 a = 1; b = 0; carry_in = 1;
        #10 a = 1; b = 1; carry_in = 0; 
        #10 a = 1; b = 1; carry_in = 1; 
        #10 $finish;
    end
endmodule