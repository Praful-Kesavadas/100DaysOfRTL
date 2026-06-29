// A 4 bit asynchronous ripple UP counter using T Flipflops

module ripple_counter_async(input clk, start, nreset, output [3:0] q);
    wire [3:0] q_bar;
    tff t1(.T(start), .nreset(nreset), .clk(clk), .q(q[0]), .q_bar(q_bar[0]));
    tff t2(.T(1'b1), .nreset(nreset), .clk(q_bar[0]), .q(q[1]), .q_bar(q_bar[1]));
    tff t3(.T(1'b1), .nreset(nreset), .clk(q_bar[1]), .q(q[2]), .q_bar(q_bar[2]));
    tff t4(.T(1'b1), .nreset(nreset), .clk(q_bar[2]), .q(q[3]), .q_bar(q_bar[3]));
endmodule
