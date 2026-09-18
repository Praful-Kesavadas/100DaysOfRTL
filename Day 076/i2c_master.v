module i2c_master #(
    parameter SYS_CLK_FREQ = 50_000_000,
    parameter I2C_BUS_FREQ = 100_000
)(
    input clk, nreset,

    input cmd_start,
    input cmd_stop,
    input cmd_read, 
    input cmd_write,
    input ack_in,
    input [7:0] tx_data,

    output reg [7:0] rx_data,
    output reg rx_ack,  // 0 -> ACK, 1 -> NACK
    output reg busy,
    output reg done,

    inout scl, sda
);

    localparam QUARTER_DIV = SYS_CLK_FREQ/(I2C_BUS_FREQ * 4);
    localparam CNT_WIDTH = $clog2(QUARTER_DIV);

    reg [CNT_WIDTH-1:0] q_cnt;
    reg [1:0] phase;
    
    wire quarter_tick = (q_cnt == (QUARTER_DIV-1));

    //Bus input synchronizer
    reg [1:0] scl_sync, sda_sync;
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            scl_sync <= 2'b11;
            sda_sync <= 2'b11;
        end
        else begin
            scl_sync <= {scl_sync[0], scl};
            sda_sync <= {sda_sync[0], sda};
        end
    end
    wire scl_in = scl_sync[1];
    wire sda_in = sda_sync[1];

    //Open drain driver registers(0 -> Drive LOW, 1 -> Release(HiZ state))
    reg scl_oen, sda_oen;

    assign scl = (scl_oen == 1'b0) ? 1'b0 : 1'bz;
    assign sda = (sda_oen == 1'b0) ? 1'b0 : 1'bz;

    //FSM States
    localparam S_IDLE = 3'd0;
    localparam S_START = 3'd1;
    localparam S_WRITE_BYTE = 3'd2;
    localparam S_READ_BYTE = 3'd3;
    localparam S_SLAVE_ACK = 3'd4;
    localparam S_MASTER_ACK = 3'd5;
    localparam S_STOP = 3'd6;

    reg [2:0] state, next_state;
    reg [2:0] bit_cnt;
    reg [7:0] shreg;
    reg stretch_active;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            q_cnt <= 0;
            phase <= 2'd0;
            stretch_active <= 1'b0;
        end
        else begin
            if(state == S_IDLE) begin
                q_cnt <= 0;
                phase <= 2'd0;
                stretch_active <= 1'b0;
            end
            else begin
                //Freeze the prescaler if slave holds SCL low during phase 1
                if(phase == 2'd1 && scl_oen == 1'b1 && scl_in == 1'b0) begin
                    stretch_active <= 1'b1;
                end
                else begin
                    stretch_active <= 1'b0;
                    if(quarter_tick) begin
                        q_cnt <= 0;
                        phase <= phase + 1'b1;
                    end
                    else q_cnt <= q_cnt + 1'b1;
                end
            end
        end
    end 

    //Next State Logic
    always@(*) begin
        next_state = state;
        case(state) 
            S_IDLE: begin
                if(cmd_start) next_state = S_START;
                else if(cmd_write) next_state = S_WRITE_BYTE;
                else if(cmd_read) next_state = S_READ_BYTE;
                else if(cmd_stop) next_state = S_STOP;
            end
            
            S_START: begin
                if(quarter_tick && phase == 2'd3) 
                    next_state = S_IDLE;
            end

            S_WRITE_BYTE: begin
                if(quarter_tick && (phase == 2'd3) && (bit_cnt == 3'd0)) 
                    next_state = S_SLAVE_ACK;
            end

            S_SLAVE_ACK: begin
                if(quarter_tick && phase == 2'd3)
                    next_state = S_IDLE;
            end

            S_READ_BYTE: begin
                if(quarter_tick && phase == 2'd3 && bit_cnt == 3'd0)
                    next_state = S_MASTER_ACK;
            end

            S_MASTER_ACK: begin
                if(quarter_tick && phase == 2'd3)
                    next_state = S_IDLE;
            end

            S_STOP: begin
                if(quarter_tick && phase == 2'd3) 
                    next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase 
    end

    //State Transition
    always@(posedge clk or negedge nreset) begin
        if(!nreset) state <= S_IDLE;
        else state <= next_state;
    end

    //Register updates
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            scl_oen <= 1'b1;
            sda_oen <= 1'b1;
            done <= 1'b0;
            rx_data <= 8'd0;
            rx_ack <= 1'b1;
            bit_cnt <= 3'd7;
            shreg <= 8'd0;
        end
        else begin
            done <= 1'b0;

            case(state)
                S_IDLE: begin
                    if(cmd_start || cmd_write) begin
                        shreg <= tx_data;
                        bit_cnt <= 3'd7;
                    end
                    else if(cmd_read) begin
                        bit_cnt <= 3'd7;
                    end
                end

                S_START: begin
                    if(quarter_tick) begin
                        case(phase)
                            2'd0: begin
                                sda_oen <= 1'b1; //Ensure SDA high before SCL goes high
                                //SCL is usually pulled LOW at the end of preceding byte or ACK cycle
                                //Hence it must remain LOW in phase 0 while SDA is floated high
                                //Otherwise floating SDA while SCL high will trigger a FALSE STOP condition
                            end
                            2'd1: begin
                                scl_oen <= 1'b1; //SCL goes HIGH
                            end
                            2'd2: begin
                                sda_oen <= 1'b0; //SDA pulled LOW while SCL HIGH(START condition)
                            end
                            2'd3: begin
                                scl_oen <= 1'b0; //SCL pulled LOW to lock bus
                                done <= 1'b1;
                            end
                        endcase
                    end
                end

                S_WRITE_BYTE: begin
                    if(quarter_tick) begin
                        case(phase)
                            2'd0: begin
                                scl_oen <= 1'b0;
                                sda_oen <= shreg[bit_cnt]; //Drive bit when SCL is low
                            end
                            2'd1: begin
                                scl_oen <= 1'b1; //Release SCL high
                            end
                            2'd2: begin
                                //  Hold data during phase 2 when SCL is high
                            end
                            2'd3: begin
                                scl_oen <= 1'b0; //Drive SCL low 
                                if(bit_cnt != 3'd0) bit_cnt <= bit_cnt - 1'b1;
                            end
                        endcase
                    end
                end

                S_SLAVE_ACK: begin
                    if(quarter_tick) begin
                        case(phase)
                            2'd0: begin
                                scl_oen <= 1'b0;
                                sda_oen <= 1'b1; //Release SDA for slave response
                            end
                            2'd1: begin
                                scl_oen <= 1'b1;
                            end
                            2'd2: begin
                                rx_ack <= sda_in; //Sample ACK
                            end
                            2'd3: begin
                                scl_oen <= 1'b0;
                                done <= 1'b1;
                            end
                        endcase
                    end
                end

                S_READ_BYTE: begin
                    if(quarter_tick) begin
                        case(phase) 
                            2'd0: begin
                                scl_oen <= 1'b0;
                                sda_oen <= 1'b1; //Release SDA so that slave can drive
                            end
                            2'd1: begin
                                scl_oen <= 1'b1;
                            end
                            2'd2: begin
                                shreg[bit_cnt] <= sda_in; //Sample incoming bit
                            end
                            2'd3: begin
                                scl_oen <= 1'b0;
                                if(bit_cnt == 3'd0) 
                                    rx_data <= {shreg[7:1], sda_in};
                                else bit_cnt <= bit_cnt - 1'b1;
                            end
                        endcase
                    end
                end

                S_MASTER_ACK: begin
                    if(quarter_tick) begin
                        case(phase)
                            2'd0: begin
                                scl_oen <= 1'b0;
                                sda_oen <= ack_in;  //Drive ACK(0) or NACK(1)
                            end
                            2'd1: begin
                                scl_oen <= 1'b1;
                            end
                            2'd2: begin
                                //Hold ACK/NACK stable
                            end
                            2'd3: begin
                                scl_oen <= 1'b0;
                                sda_oen <= 1'b1;
                                done <= 1'b1;
                            end
                        endcase
                    end 
                end

                //In stop we want the sda to rise while scl is high
                S_STOP: begin
                    if(quarter_tick) begin
                        case(phase)
                            2'd0: begin
                                scl_oen <= 1'b0;
                                sda_oen <= 1'd0;
                            end
                            2'd1: begin
                                scl_oen <= 1'b1;
                            end
                            2'd2: begin
                                sda_oen <= 1'b1; //SDA rise while SCL 1(STOP condition)
                            end
                            2'd3: begin
                                done <= 1'b1;
                            end
                        endcase
                    end
                end
                default: ;
            endcase
        end
    end

    always@(*) begin
        busy = (state != S_IDLE);
    end
    
endmodule