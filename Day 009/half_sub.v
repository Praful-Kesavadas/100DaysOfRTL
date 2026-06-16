module half_sub(input a, b, output difference, borrow);
    assign difference = a ^ b;
    assign borrow = (~a) & b; // 0 - 1 should trigger borrow bit
endmodule
