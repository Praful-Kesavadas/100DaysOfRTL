module round_robin_arbiter#(parameter NUM_REQS = 8
)(
    input clk, nreset, grant_ready,
    input [NUM_REQS-1:0] requests,
    output reg [NUM_REQS-1:0] grant
);
    reg [NUM_REQS-1:0] grant_last;
    wire [NUM_REQS-1:0] mask = grant_last ^ (~grant_last + 1'b1);
    wire [NUM_REQS-1:0] requests_masked = requests & mask;
    wire [NUM_REQS-1:0] grant_unmasked = requests & (~requests + 1'b1);
    wire [NUM_REQS-1:0] grant_masked = requests_masked & (~requests_masked + 1'b1);
    wire [NUM_REQS-1:0]grant_next = (grant_masked != 0) ? grant_masked : grant_unmasked;
    always@(posedge clk or negedge nreset)begin
        if(!nreset) begin
            grant <= 0;
            grant_last <= 0;
        end
        else if(grant_ready) begin
            grant <= grant_next;
            if(grant_next != 0) begin
                grant_last <= grant_next;
            end 
        end 
    end 
endmodule
