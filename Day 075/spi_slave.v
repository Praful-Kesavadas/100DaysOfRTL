module spi_slave #(
    parameter DATA_WIDTH = 8
)(
    input clk, nreset,

    //Config modes
    input cpol, cpha,

    //Datapath interface
    input [DATA_WIDTH-1:0] tx_data,
    output reg [DATA_WIDTH-1:0] rx_data,
    output reg rx_valid,

    //SPI Bus lines
    input sclk,
    input mosi,
    output miso,
    input ss_n
);
    localparam CNT_WIDTH = $clog2(DATA_WIDTH);

    //2 stage CDC Synchronizer
    reg [1:0] sclk_sync_reg, ss_n_sync_reg, mosi_sync_reg;
    reg sclk_prev, ss_n_prev;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            sclk_sync_reg <= 2'b00;
            ss_n_sync_reg <= 2'b11;
            mosi_sync_reg <= 2'b00;
            sclk_prev <= 1'b0;
            ss_n_prev <= 1'b1;
        end
        else begin
            sclk_sync_reg <= {sclk_sync_reg[0], sclk};
            ss_n_sync_reg <= {ss_n_sync_reg[0], ss_n};
            mosi_sync_reg <= {mosi_sync_reg[0], mosi};
            ss_n_prev <= ss_n_sync_reg[1];
            sclk_prev <= sclk_sync_reg[1];
        end
    end

    wire ss_n_sync = ss_n_sync_reg[1];
    wire sclk_sync = sclk_sync_reg[1];
    wire mosi_sync = mosi_sync_reg[1];

    //Edge detection
    wire sclk_rising = (sclk_prev == 1'b0 && sclk_sync == 1'b1);
    wire sclk_falling = (sclk_prev == 1'b1 && sclk_sync == 1'b0);
    wire ss_n_falling = (ss_n_prev == 1'b1 && ss_n_sync == 1'b0);

    wire is_leading_edge = (cpol == 1'b0) ? sclk_rising : sclk_falling;
    wire is_trailing_edge = (cpol == 1'b0) ? sclk_falling : sclk_rising;

    wire sample_edge = (cpha == 1'b0) ? is_leading_edge : is_trailing_edge;
    wire shift_edge = (cpha == 1'b0) ? is_trailing_edge : is_leading_edge;

    //Shift registers and sequencers
    reg [DATA_WIDTH-1:0] tx_shreg, rx_shreg;
    reg [CNT_WIDTH-1:0] bit_cnt;
    reg miso_reg;

    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            rx_data <= 0;
            rx_valid <= 0;
            tx_shreg <= 0;
            rx_shreg <= 0;
            bit_cnt <= 0;
            miso_reg <= 0;
        end
        else begin
            rx_valid <= 0;

            if(ss_n_sync) begin
                bit_cnt <= 0;
                miso_reg <= 0;
            end
            else if(ss_n_falling) begin
                bit_cnt <= 0; //Initialize

                if(cpha == 1'b0) begin //Drive MSB immediately
                    miso_reg <= tx_data[DATA_WIDTH-1];
                    tx_shreg <= {tx_data[DATA_WIDTH-2:0], 1'b0};
                end
                else begin
                    tx_shreg <= tx_data;
                    miso_reg <= 1'b0;
                end
            end
            else begin
                if(shift_edge) begin
                    miso_reg <= tx_shreg[DATA_WIDTH-1];
                    tx_shreg <= {tx_shreg[DATA_WIDTH-2:0], 1'b0};
                end
                if(sample_edge) begin
                    rx_shreg <= {rx_shreg[DATA_WIDTH-2:0], mosi_sync};

                    if(bit_cnt == DATA_WIDTH - 1) begin
                        rx_data <= {rx_shreg[DATA_WIDTH-2:0], mosi_sync};
                        rx_valid <= 1'b1;
                        bit_cnt <= 0;
                    end
                    else begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end
            end
        end
    end

    //Tristate Misodriver
    assign miso = (!ss_n_sync) ? miso_reg : 1'bz;
endmodule