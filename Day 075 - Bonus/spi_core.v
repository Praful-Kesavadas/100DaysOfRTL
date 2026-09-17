module spi_core#(
    parameter DATA_WIDTH = 8,
    parameter CLK_DIV = 8
)(
    input clk, nreset,

    //Configuration
    input loopback_en, cpol, cpha,

    //Master interface
    input m_start,
    input [DATA_WIDTH-1:0] m_tx_data,
    output [DATA_WIDTH-1:0] m_rx_data,
    output m_busy, m_done,

    //Slave Interface
    input [DATA_WIDTH-1:0] s_tx_data,
    output [DATA_WIDTH-1:0] s_rx_data,
    output s_rx_valid,

    //External SPI Pins
    output sclk_out, mosi_out, ss_n_out,
    input miso_in,

    input sclk_in, mosi_in, ss_n_in,
    output miso_out
);

    wire m_sclk, m_mosi, m_ss_n, m_miso;
    wire s_sclk, s_mosi, s_ss_n, s_miso;

    //Loopback MUX
    assign s_sclk = (loopback_en) ? m_sclk : sclk_in;
    assign s_mosi = (loopback_en) ? m_mosi : mosi_in;
    assign s_ss_n = (loopback_en) ? m_ss_n : ss_n_in;
    
    assign m_miso = (loopback_en) ? s_miso : miso_in;

    //External Bus Drivers
    assign sclk_out = m_sclk;
    assign mosi_out = m_mosi;
    assign ss_n_out = m_ss_n;
    assign miso_out = s_miso;

    //Master module
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_DIV(CLK_DIV)
    ) master (
        .clk(clk),
        .nreset(nreset),
        .cpol(cpol),
        .cpha(cpha),
        .start(m_start),
        .tx_data(m_tx_data), 
        .rx_data(m_rx_data),
        .busy(m_busy),
        .done(m_done),
        .sclk(m_sclk),
        .mosi(m_mosi),
        .miso(m_miso), 
        .ss_n(m_ss_n)
    );

    //Slave Module
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) slave (
        .clk(clk),
        .nreset(nreset),
        .cpol(cpol),
        .cpha(cpha),
        .tx_data(s_tx_data),
        .rx_data(s_rx_data),
        .rx_valid(s_rx_valid),
        .sclk(s_sclk), 
        .mosi(s_mosi),
        .miso(s_miso),
        .ss_n(s_ss_n)
    );

endmodule