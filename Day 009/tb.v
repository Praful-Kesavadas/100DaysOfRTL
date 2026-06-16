module tb_full_sub();
    reg a, b, borrow_in;
    wire difference, borrow_out;

    full_sub uut(.a(a), .b(b), .borrow_in(borrow_in), .difference(difference), .borrow_out(borrow_out));

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
        $monitor("Time: %0d ns | Inputs: A = %d, B = %d, Borrow_in = %d | Outputs: Diff = %d, B_out = %d", $time, a, b, borrow_in, difference, borrow_out);
    end

    initial begin
        a = 1'b0; b = 1'b0; borrow_in = 1'b0; #10;
        
        a = 1'b0; b = 1'b0; borrow_in = 1'b1; #10; 
        a = 1'b0; b = 1'b1; borrow_in = 1'b0; #10; 
        a = 1'b0; b = 1'b1; borrow_in = 1'b1; #10; 
        
        a = 1'b1; b = 1'b0; borrow_in = 1'b0; #10; 
        a = 1'b1; b = 1'b0; borrow_in = 1'b1; #10; 
        a = 1'b1; b = 1'b1; borrow_in = 1'b0; #10; 
        a = 1'b1; b = 1'b1; borrow_in = 1'b1; #10; 
        
        a = 1'b0; b = 1'b0; borrow_in = 1'b0; #10;
        
        $finish;
    end
endmodule