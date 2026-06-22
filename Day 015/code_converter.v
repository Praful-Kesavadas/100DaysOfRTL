// A bidirectional code converter, i.e. both gray code to binary and vice versa
// Mode = 0 for binary to gray, Mode = 1 for gray to binary
// Idea: For converting binary to gray, use G[i] = B[i] ^ B[i+1]
//       For gray to binary, use B[MSB] = G[MSB], B[MSB - 1] = B[MSB] ^ G[MSB-1], B[MSB-2] = B[MSB-1] ^ G[MSB-2], B[MSB-3] = B[MSB-2] ^ G[MSB-3]

module code_converter(input [3:0] data_in, input mode, output [3:0] converted);
    wire [3:0] gray_to_binary_out, binary_to_gray_out;

    assign binary_to_gray_out = data_in ^  (data_in >> 1); 
    assign gray_to_binary_out[3] = data_in[3];
    assign gray_to_binary_out[2] = gray_to_binary_out[3] ^ data_in[2];
    assign gray_to_binary_out[1] = gray_to_binary_out[2] ^ data_in[1];
    assign gray_to_binary_out[0] = gray_to_binary_out[1] ^ data_in[0];

    assign converted = mode ? gray_to_binary_out : binary_to_gray_out;
endmodule

