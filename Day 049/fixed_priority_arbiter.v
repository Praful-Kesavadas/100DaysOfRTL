module fixed_priority_arbiter#(parameter NUM_REQS = 8
)(
    input clk, nreset, grant_ready,
    input [NUM_REQS-1:0] requests,
    output reg [NUM_REQS-1:0] grant
);

    wire [NUM_REQS-1:0] next_grant = requests & (~requests + 1'b1); //To extract lowest HIGH bit(highest priority for Agent 0)

    always@(posedge clk or negedge nreset) begin
        if(!nreset) grant <= 0;
        else if(grant_ready) grant <= next_grant;
    end
endmodule
