//A 3:8 decoder by using conditional operation with left shift
module decoder3to8(input en, input [2:0] sel, output [7:0] out);
    assign out = (en) ? (8'd1 << sel) : 8'd0;
endmodule
