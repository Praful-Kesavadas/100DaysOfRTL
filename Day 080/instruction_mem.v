module instruction_mem #(
    parameter MEM_DEPTH = 64,
    parameter MEM_FILE = "program.mem"
)(
    input [31:0] addr,
    output [31:0] rdata
);
    localparam ADDR_WIDTH = $clog2(MEM_DEPTH);

    reg [31:0] rom [0: MEM_DEPTH-1];
    assign rdata = rom[addr[ADDR_WIDTH+1:2]];

    integer i;

    initial begin
        for(i=0; i < MEM_DEPTH; i = i+1) begin
            rom[i] = 32'h0000_0013;
        end

        if(MEM_FILE != "") begin
            $readmemh(MEM_FILE, rom);
        end
    end
endmodule