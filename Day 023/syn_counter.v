module syn_counter(input clk, count_up, nreset, output [3:0] q);
    wire [3:0] T, q_bar;
    assign T[0] = 1'b1;
    assign T[1] = count_up & q[0] | ~(count_up) & q_bar[0];
    assign T[2] = count_up & q[1] & q[0] | ~(count_up) & q_bar[1] & q_bar[0];
    assign T[3] = count_up & q[2] & q[1] & q[0] | ~(count_up) & q_bar[2] & q_bar[1] & q_bar[0];

    tff t1(.T(T[0]), .clk(clk), .nreset(nreset), .q(q[0]), .q_bar(q_bar[0]));
    tff t2(.T(T[1]), .clk(clk), .nreset(nreset), .q(q[1]), .q_bar(q_bar[1]));
    tff t3(.T(T[2]), .clk(clk), .nreset(nreset), .q(q[2]), .q_bar(q_bar[2]));
    tff t4(.T(T[3]), .clk(clk), .nreset(nreset), .q(q[3]), .q_bar(q_bar[3]));

endmodule
