module spi_master #(
    parameter DATA_WIDTH = 8,
    parameter CLK_DIV = 4 //The factor by which original clock freq has to be divided to get the spi clk
)(
    input clk, nreset,

    //Configuration modes
    input cpol, //Clock polarity (0 = sclk is active high, leading edge is rising edge)
    input cpha, //Clock Phase (0 = data sampled on the leading edge and shifted on trailing edge)

    //Host control
    input start, 
    input [DATA_WIDTH-1:0] tx_data,
    output reg [DATA_WIDTH-1:0] rx_data,
    output reg busy, done,

    //SPI Bus lines
    output reg sclk,
    output reg mosi, //Master-out slave-in
    input miso,     //Master-in Slave-Out
    output reg ss_n //Slave select(active low)
);
    localparam HALF_DIV = CLK_DIV/2;
    localparam CNT_WIDTH = $clog2(HALF_DIV);

    //FSM States
    localparam S_IDLE = 2'd0;
    localparam S_SETUP = 2'd1;
    localparam S_TRANS = 2'd2;
    localparam S_HOLD = 2'd3;

    reg [1:0] state, next_state;
    reg [CNT_WIDTH-1:0] clk_cnt;
    reg [4:0] edge_cnt; //Counts 16 half edges from 0 to 15
    reg [DATA_WIDTH-1:0] tx_shreg;
    reg [DATA_WIDTH-1:0] rx_shreg;

    wire half_tick = (clk_cnt == (HALF_DIV-1));

    wire is_leading_edge = (edge_cnt[0] == 1'b0);
    wire is_trailing_edge = (edge_cnt[0] == 1'b1);

    wire sample_edge = (cpha == 1'b0) ? is_leading_edge : is_trailing_edge;
    wire shift_edge = (cpha == 1'b0) ? is_trailing_edge : is_leading_edge;

    //Prescaler counter
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            clk_cnt <= 0;
        end
        else begin
            if(state == S_IDLE) clk_cnt <= 0;
            else if(half_tick) clk_cnt <= 0;
            else clk_cnt <= clk_cnt + 1'b1;
        end
    end

    //State transition
    always@(posedge clk or negedge nreset) begin
        if(!nreset) state <= S_IDLE;
        else state <= next_state;
    end

    //Next State Logic
    always@(*) begin
        next_state = state;
        case(state)
            S_IDLE: begin
                if(start) next_state = S_SETUP;
            end
            S_SETUP: begin
                if(half_tick) next_state = S_TRANS;
            end
            S_TRANS: begin
                if(half_tick && (edge_cnt == (DATA_WIDTH*2 -1))) next_state = S_HOLD;
            end
            S_HOLD: begin
                if(half_tick) next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            sclk <= 1'b0;
            mosi <= 1'b0;
            ss_n <= 1'b1;
            done <= 1'b0;
            edge_cnt <= 5'd0;
            tx_shreg <= 0;
            rx_shreg <= 0;
            rx_data <= 0;
        end
        else begin
            done <= 1'b0;

            case(state)
                S_IDLE: begin
                    sclk <= cpol;
                    ss_n <= 1'b1;
                    edge_cnt <= 5'd0;

                    if(start) begin
                        ss_n <= 1'b0;
                        
                        // If data sampled on leading edge, MSB must be driven to mosi before the first leading edge occurs
                        if(cpha == 1'b0)begin
                            mosi <= tx_data[DATA_WIDTH-1];
                            tx_shreg <= {tx_data[DATA_WIDTH-2:0], 1'b0};
                        end 
                        else begin
                            mosi <= 1'b0;
                            tx_shreg <= tx_data;
                        end
                    end
                end
                S_SETUP: begin
                        edge_cnt <= 5'd0;
                end
                S_TRANS: begin
                    if(half_tick) begin
                        sclk = ~sclk;
                        edge_cnt <= edge_cnt + 1'b1;

                        if(sample_edge) rx_shreg <= {rx_shreg[DATA_WIDTH-2:0], miso};
                        if(shift_edge) begin
                            mosi <= tx_shreg[DATA_WIDTH-1];
                            tx_shreg <= {tx_shreg[DATA_WIDTH-2:0], 1'b0};
                        end
                    end
                end
                S_HOLD: begin
                    if(half_tick) begin
                        ss_n <= 1'b1;
                        done <= 1'b1;
                        rx_data <= rx_shreg;
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