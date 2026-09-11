module direct_mapped_cache #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LINE_COUNT = 8,
    parameter INDEX_BITS = $clog2(LINE_COUNT),
    parameter TAG_BITS = ADDR_WIDTH - INDEX_BITS
)(
    input clk, nreset,

    //CPU Interface
    input cpu_req,  //High when CPU initiates transaction
    input cpu_wr,   // 1: Write, 0: Read
    input [ADDR_WIDTH-1:0] cpu_addr, //Address requested by CPU
    input [DATA_WIDTH-1:0] cpu_wdata, //Data to be written to the above address
    output reg [DATA_WIDTH-1:0] cpu_rdata,  // If read, this line is loaded with the data from memory
    output reg cpu_ready,   //High when transaction completes

    //Memory Side
    output reg mem_req,    // Requesting data from memory
    output reg mem_wr,     // 1: Write enable, 0: Read operation
    output reg [DATA_WIDTH-1:0] mem_wdata,  //To write data into memory
    output reg [ADDR_WIDTH-1:0] mem_addr,   //Address to write the data
    input [DATA_WIDTH-1:0] mem_rdata,   // Data coming from the RAM
    input mem_ready     //When the memory has completed the transaction
);
    //Cache Internal Storage Arrays
    reg [DATA_WIDTH-1:0] data_array [0:LINE_COUNT-1];
    reg [TAG_BITS-1:0] tag_array [0:LINE_COUNT-1];
    reg valid_array[0:LINE_COUNT-1];
    reg dirty_array[0:LINE_COUNT-1];    // If any data is modified relative to DRAM

    // Address decoding
    wire [INDEX_BITS-1:0] index = cpu_addr[INDEX_BITS-1:0];
    wire [TAG_BITS-1:0] tag = cpu_addr[ADDR_WIDTH-1:INDEX_BITS];

    //States 
    localparam S_IDLE = 2'd0;
    localparam S_COMP_TAG = 2'd1;
    localparam S_WB = 2'd2;
    localparam S_ALLOCATE = 2'd3;

    reg [1:0] state, next_state;

    //Hit detect
    wire is_hit = valid_array[index] && (tag_array[index] == tag);

    //Next state logic
    always@(*) begin
        next_state = state;
        case(state)
            S_IDLE: begin
                if(cpu_req) next_state = S_COMP_TAG;
            end
            S_COMP_TAG: begin
                if(is_hit) next_state = S_IDLE; //Cache hit: hence no need for any operation from memory side
                else begin
                    //If the data present is a new data, we have to write it back into memory first before allocating the new data
                    if(valid_array[index] && dirty_array[index]) next_state = S_WB;
                    else next_state = S_ALLOCATE;
                end
            end
            S_WB: begin
                if(mem_ready) next_state = S_ALLOCATE;
            end
            S_ALLOCATE: begin
                if(mem_ready) next_state = S_COMP_TAG;
            end
            default: next_state = S_IDLE;
        endcase
    end

    //State transition
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            state <= S_IDLE;
        end
        else state <= next_state;
    end

    //Synchronous valid and data array updates
    integer i;
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            for(i=0; i< LINE_COUNT; i=i+1) begin
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0;
            end
        end
        else begin
            case(state)
                S_COMP_TAG: begin
                    if(is_hit && cpu_wr) begin
                        data_array[index] <= cpu_wdata;
                        dirty_array[index] <= 1'b1;
                    end
                end
                S_ALLOCATE: begin
                    if(mem_ready) begin
                        data_array[index] <= mem_rdata;
                        tag_array[index] <= tag;
                        valid_array[index] <= 1'b1;
                        dirty_array[index] <= 1'b0; //Marked Clean(allocation only after write back)
                    end
                end
                default: begin
                    //Hold
                end
            endcase  
        end
    end

    //Output logic
    always@(*) begin
        cpu_ready = 1'b0;
        cpu_rdata = 0;
        mem_req = 0;
        mem_wr = 0;
        mem_addr = 0;
        mem_wdata = 0;

        case(state)
            //If hit and read, then data passed to cpu_rdata. If cpu_wr, then data is written into the cache line and dirty asserted(handled in previous sync fsm)
            S_COMP_TAG: begin
                if(is_hit) begin
                    cpu_ready = 1'b1;
                    if(!cpu_wr) cpu_rdata = data_array[index];
                end
            end
            S_WB: begin
                mem_req = 1'b1;
                mem_wr = 1'b1;
                mem_addr = {tag_array[index], index};
                mem_wdata = data_array[index];
            end
            S_ALLOCATE: begin
                mem_req = 1'b1;
                mem_wr = 1'b0;
                mem_addr = cpu_addr;
            end
            default: begin
              
            end 
        endcase 
    end
endmodule