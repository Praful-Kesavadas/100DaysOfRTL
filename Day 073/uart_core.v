module uart_core #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input clk, nreset,
    input loopback_en,

    //Transmitter
    input tx_start, 
    input [7:0] tx_data,
    output tx_busy,
    output tx_done,

    //Receiver
    output [7:0] rx_data,
    output rx_valid,
    output rx_busy,
    output framing_error,

    //Data pins
    input rx_serial,
    output tx_serial
);
    //Receive external input data if not feedback
    wire rx_internal = (loopback_en) ? tx_serial : rx_serial;

    //Transmitter Instantiate
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) transmitter (
        .clk(clk),
        .nreset(nreset),
        .tx_start(tx_start),
        .d_in(tx_data),
        .tx_serial(tx_serial),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .OVERSAMPLE(16)
    ) receiver (
        .clk(clk),
        .nreset(nreset),
        .rx_in(rx_internal),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_busy(rx_busy),
        .framing_error(framing_error)
    );

endmodule