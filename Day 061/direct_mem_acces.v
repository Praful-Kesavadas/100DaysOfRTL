module dma_controller#(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 32
)(
    input clk, nreset,

    //CPU Signals
    input start, 
    input irq_ack, //CPU tells that it acknowledged the interrupt req
    input [ADDR_WIDTH-1:0] src_addr_in, 
    input [ADDR_WIDTH-1:0] dest_addr_in,
    input [15:0] transfer_len_in, //Total words to transfer
    input src_inc_in, // If 1 -> Increment the source register addr, else fixed
    input dest_inc_in, // If 1 -> Increment the destination register addr

    //Status and Interrupt Signals
    output reg busy, done_irq, error,

    //Bus interface
    output reg bus_req,
    output reg bus_write,   // 0 -> Read, 1 -> write
    output reg [ADDR_WIDTH-1:0] bus_addr,
    output reg [DATA_WIDTH-1:0] bus_wdata,
    input [DATA_WIDTH-1:0] bus_rdata,
    input bus_ack
);
    //Byte stride per word
    localparam BYTES_PER_WORD = DATA_WIDTH / 8;

    //States
    localparam IDLE = 3'b000;
    localparam READ_SRC = 3'b001;
    localparam WRITE_DEST = 3'b010;
    localparam UPDATE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;

    //Internal Registers
    reg [ADDR_WIDTH-1:0] current_src;
    reg [ADDR_WIDTH-1:0] current_dest;
    reg [15:0] rem_len;
    reg src_inc;
    reg dest_inc;
    reg [DATA_WIDTH-1:0] data_buffer;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            state <= IDLE;
            busy <= 0;
            done_irq <= 0;
            error <= 0;
            bus_req <= 0;
            bus_write <= 0;
            bus_addr <= 0;
            bus_wdata <= 0;
            current_dest <= 0;
            current_src <= 0;
            rem_len <= 0;
            src_inc <= 0;
            dest_inc <= 0;
            data_buffer <= 0;
        end
        else begin
            case(state)
                IDLE: begin
                    bus_req <= 0;
                    bus_write <= 0;
                    if(start) begin
                        done_irq <= 0;
                        error <= 0;
                        if(transfer_len_in == 16'd0) begin
                            busy <= 1'b0;
                            state <= DONE;
                        end
                        else begin
                            busy <= 1'b1;
                            rem_len <= transfer_len_in;
                            current_src <= src_addr_in;
                            current_dest <= dest_addr_in;
                            src_inc <= src_inc_in;
                            dest_inc <= dest_inc_in;
                            state <= READ_SRC;
                        end
                    end
                end
                READ_SRC: begin
                    bus_req <= 1'b1;
                    bus_write <= 1'b0; //Read mode
                    bus_addr <= current_src;

                    if(bus_ack) begin
                        data_buffer <= bus_rdata;
                        bus_req <= 0; //Request Line is cleared
                        state <= WRITE_DEST;
                    end
                end
                WRITE_DEST:  begin
                    bus_req <= 1'b1;
                    bus_write <= 1'b1; //Write mode
                    bus_addr <= current_dest;
                    bus_wdata <= data_buffer;
                    if(bus_ack) begin
                        bus_req <= 0;
                        state <= UPDATE;
                    end
                end
                UPDATE: begin
                    if(src_inc) current_src <= current_src + BYTES_PER_WORD;
                    if(dest_inc) current_dest <= current_dest + BYTES_PER_WORD;

                    if(rem_len == 16'd1) begin
                        rem_len <= 0;
                        busy <= 0;
                        state <= DONE;
                    end
                    else begin
                        rem_len <= rem_len - 16'd1;
                        state <= READ_SRC;
                    end
                end
                DONE: begin
                    busy <= 0;
                    done_irq <= 1'b1;

                    if(irq_ack) begin
                        done_irq <= 1'b0;
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule