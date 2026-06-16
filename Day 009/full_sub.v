module full_sub(input a, b, borrow_in, output difference, borrow_out);
    wire diff1, borrow1, borrow2;
    half_sub s1(.a(a), .b(b), .difference(diff1), .borrow(borrow1));
    half_sub s2(.a(diff1), .b(borrow_in), .difference(difference), .borrow(borrow2));

    assign borrow_out = borrow1 | borrow2;
endmodule
