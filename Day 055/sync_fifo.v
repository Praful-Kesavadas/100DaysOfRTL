module syn_fifo #(
    parameter DEPTH                = 16,
    parameter DATA_WIDTH           = 8,
    parameter ALMOST_FULL_THRESH   = 12,
    parameter ALMOST_EMPTY_THRESH  = 4,
    parameter ADDR_WIDTH          = $clog2(DEPTH)
)(
    input clk, nreset, 
    input write_en, read_en,
    input [DATA_WIDTH-1:0] data_in, 
    output reg [DATA_WIDTH-1:0] data_out,
    output almost_full, almost_empty, empty, full
);

    // Internal Memory & Control Registers
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH:0]   wr_ptr;
    reg [ADDR_WIDTH:0]   rd_ptr;
    reg [ADDR_WIDTH:0]   fifo_cnt;

    // Control Strobes (Allows Push on FULL if simultaneous Pop occurs)
    wire wr_valid = write_en && (!full || read_en);
    wire rd_valid = read_en  && !empty;

    //Synchronous RAM Write (Pure Clocked -> Infers dedicated BRAM)
    always @(posedge clk) begin
        if (wr_valid) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= data_in;
        end
    end

    //Write Pointer Advancement
    always @(posedge clk or negedge nreset) begin
        if (!nreset) begin
            wr_ptr <= 0;
        end
        else if (wr_valid) begin
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    //Read Operation & Read Pointer Advancement (Gated by rd_valid)
    always @(posedge clk or negedge nreset) begin
        if (!nreset) begin
            rd_ptr   <= 0;
            data_out <= 0;
        end
        else if (rd_valid) begin
            data_out <= mem[rd_ptr[ADDR_WIDTH-1:0]];
            rd_ptr   <= rd_ptr + 1'b1;
        end
    end

    //Occupancy Counter Tracking
    always @(posedge clk or negedge nreset) begin
        if (!nreset) begin
            fifo_cnt <= 0;
        end
        else begin
            case ({wr_valid, rd_valid})
                2'b10:   fifo_cnt <= fifo_cnt + 1'b1; // Push only
                2'b01:   fifo_cnt <= fifo_cnt - 1'b1; // Pop only
                default: fifo_cnt <= fifo_cnt;        // Simultaneous Push/Pop or Idle
            endcase
        end
    end
    
    //Status Flags
    assign empty        = (fifo_cnt == 0);
    assign full         = (fifo_cnt == DEPTH);
    assign almost_empty = (fifo_cnt <= ALMOST_EMPTY_THRESH);
    assign almost_full  = (fifo_cnt >= ALMOST_FULL_THRESH);

endmodule