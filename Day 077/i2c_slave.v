`timescale 1ns / 1ps

module i2c_slave_eeprom #(
    parameter [6:0] SLAVE_ADDR = 7'h50, // Standard 7-bit EEPROM base address
    parameter       MEM_DEPTH  = 256
)(
    input  wire clk,
    input  wire nreset,

    input  wire scl,
    inout  wire sda
);

    // -----------------------------------------------------------------
    // 1. Two-Stage CDC Synchronizer & History Registers
    // -----------------------------------------------------------------
    reg [1:0] scl_sync_reg, sda_sync_reg;
    reg       scl_prev, sda_prev;

    always @(posedge clk or negedge nreset) begin
        if (!nreset) begin
            sda_prev     <= 1'b1;
            scl_prev     <= 1'b1;
            sda_sync_reg <= 2'b11;
            scl_sync_reg <= 2'b11;
        end else begin
            scl_sync_reg <= {scl_sync_reg[0], scl};
            sda_sync_reg <= {sda_sync_reg[0], sda};
            sda_prev     <= sda_sync_reg[1];
            scl_prev     <= scl_sync_reg[1];
        end 
    end

    wire scl_sync = scl_sync_reg[1];
    wire sda_sync = sda_sync_reg[1];

    // -----------------------------------------------------------------
    // 2. Edge and Framing Event Detectors
    // -----------------------------------------------------------------
    wire scl_rising  = (scl_prev == 1'b0 && scl_sync == 1'b1);
    wire scl_falling = (scl_prev == 1'b1 && scl_sync == 1'b0);

    // START: SDA falls while SCL is HIGH
    wire start_detect = (scl_sync == 1'b1 && sda_prev == 1'b1 && sda_sync == 1'b0);

    // STOP: SDA rises while SCL is HIGH
    wire stop_detect  = (scl_sync == 1'b1 && sda_prev == 1'b0 && sda_sync == 1'b1);

    // -----------------------------------------------------------------
    // 3. FSM States
    // -----------------------------------------------------------------
    localparam S_IDLE       = 4'd0;
    localparam S_START      = 4'd1; // Absorbs initial falling edge of START
    localparam S_DEV_ADDR   = 4'd2;
    localparam S_DEV_ACK    = 4'd3;
    localparam S_WORD_ADDR  = 4'd4;
    localparam S_WORD_ACK   = 4'd5;
    localparam S_WRITE_DATA = 4'd6;
    localparam S_WRITE_ACK  = 4'd7;
    localparam S_READ_DATA  = 4'd8;
    localparam S_READ_ACK   = 4'd9;

    reg [3:0] state, next_state;

    reg [2:0] bit_cnt;
    reg [7:0] shreg, mem_addr, tx_shreg;
    reg       rw_mode; // 0 -> Write, 1 -> Read
    reg       master_ack;

    // Internal Memory Array with Synthesis-Friendly Power-up Init
    reg [7:0] memory [0:MEM_DEPTH-1];
    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            memory[i] = i[7:0];
        end
    end

    // Open Drain Driver Reg (0 -> Drive LOW, 1 -> Float/Hi-Z)
    reg sda_oen;
    assign sda = (sda_oen == 1'b0) ? 1'b0 : 1'bz;

    // -----------------------------------------------------------------
    // 4. Combinational Next-State Logic
    // -----------------------------------------------------------------
    always @(*) begin
        next_state = state;

        if (start_detect) begin
            next_state = S_START;
        end else if (stop_detect) begin
            next_state = S_IDLE;
        end else if (scl_falling) begin
            case (state)
                S_START: begin
                    next_state = S_DEV_ADDR;
                end

                S_DEV_ADDR: begin
                    if (bit_cnt == 3'd0) begin
                        if (shreg[7:1] == SLAVE_ADDR)
                            next_state = S_DEV_ACK;
                        else
                            next_state = S_IDLE;
                    end
                end

                S_DEV_ACK: begin
                    if (rw_mode == 1'b0)
                        next_state = S_WORD_ADDR;
                    else
                        next_state = S_READ_DATA;
                end

                S_WORD_ADDR: begin
                    if (bit_cnt == 3'd0)
                        next_state = S_WORD_ACK;
                end 

                S_WORD_ACK: begin
                    next_state = S_WRITE_DATA;
                end

                S_WRITE_DATA: begin
                    if (bit_cnt == 3'd0)
                        next_state = S_WRITE_ACK;
                end

                S_WRITE_ACK: begin
                    next_state = S_WRITE_DATA; // Support sequential page writes
                end

                S_READ_DATA: begin
                    if (bit_cnt == 3'd0)
                        next_state = S_READ_ACK;
                end

                S_READ_ACK: begin
                    if (master_ack == 1'b0)
                        next_state = S_READ_DATA; // Master ACKed -> continue sequential read
                    else
                        next_state = S_IDLE;      // Master NACKed -> free the bus
                end

                default: next_state = S_IDLE;
            endcase 
        end
    end

    // -----------------------------------------------------------------
    // 5. Sequential State Transition
    // -----------------------------------------------------------------
    always @(posedge clk or negedge nreset) begin
        if (!nreset)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // -----------------------------------------------------------------
    // 6. Datapath & Register Updates
    // -----------------------------------------------------------------
    always @(posedge clk or negedge nreset) begin
        if (!nreset) begin
            bit_cnt    <= 3'd7;
            shreg      <= 8'd0;
            mem_addr   <= 8'd0;
            tx_shreg   <= 8'd0;
            rw_mode    <= 1'b0;
            master_ack <= 1'b1;
            sda_oen    <= 1'b1;
        end else if (start_detect) begin
            bit_cnt <= 3'd7;
            sda_oen <= 1'b1;
        end else if (stop_detect) begin
            sda_oen <= 1'b1;
        end else begin
            // Synchronous Sampling on SCL Rising Edge
            if (scl_rising) begin
                case (state) 
                    S_DEV_ADDR, S_WORD_ADDR, S_WRITE_DATA: begin
                        shreg <= {shreg[6:0], sda_sync};
                    end

                    S_READ_ACK: begin
                        master_ack <= sda_sync;
                    end

                    default: ;
                endcase
            end

            // Synchronous Driving on SCL Falling Edge
            else if (scl_falling) begin
                case (state)
                    S_START: begin
                        bit_cnt <= 3'd7;
                        sda_oen <= 1'b1;
                    end

                    S_DEV_ADDR: begin
                        if (bit_cnt == 3'd0) begin
                            rw_mode <= shreg[0];
                            if (shreg[7:1] == SLAVE_ADDR)
                                sda_oen <= 1'b0; // ACK
                            else
                                sda_oen <= 1'b1; // NACK
                            bit_cnt <= 3'd7;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end

                    S_DEV_ACK: begin
                        bit_cnt <= 3'd7;
                        if (rw_mode == 1'b0) begin
                            sda_oen <= 1'b1; // Release SDA for word address input
                        end else begin
                            tx_shreg <= memory[mem_addr];
                            sda_oen  <= memory[mem_addr][7]; // Output MSB
                        end
                    end

                    S_WORD_ADDR: begin
                        if (bit_cnt == 3'd0) begin
                            mem_addr <= shreg;
                            sda_oen  <= 1'b0; // ACK
                            bit_cnt  <= 3'd7;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end

                    S_WORD_ACK: begin
                        bit_cnt <= 3'd7;
                        sda_oen <= 1'b1; // Release SDA for data write input
                    end

                    S_WRITE_DATA: begin
                        if (bit_cnt == 3'd0) begin
                            memory[mem_addr] <= shreg;
                            mem_addr         <= mem_addr + 1'b1;
                            sda_oen          <= 1'b0; // ACK
                            bit_cnt          <= 3'd7;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end

                    S_WRITE_ACK: begin
                        bit_cnt <= 3'd7;
                        sda_oen <= 1'b1;
                    end

                    S_READ_DATA: begin
                        if (bit_cnt == 3'd0) begin
                            sda_oen <= 1'b1; // Release SDA for master ACK/NACK
                            bit_cnt <= 3'd7;
                        end else begin
                            sda_oen <= tx_shreg[bit_cnt - 1];
                            bit_cnt <= bit_cnt - 1'b1;
                        end 
                    end

                    S_READ_ACK: begin
                        if (master_ack == 1'b0) begin
                            mem_addr <= mem_addr + 1'b1;
                            tx_shreg <= memory[mem_addr + 1'b1];
                            sda_oen  <= memory[mem_addr + 1'b1][7];
                            bit_cnt  <= 3'd7;
                        end else begin
                            sda_oen <= 1'b1; // Master NACK: release bus  
                        end 
                    end 

                    default: ;
                endcase
            end
        end
    end

endmodule