// A stopwatch/timer module with start, pause, split lap and clear controls

module stopwatch #(
    parameter FREQ_MHz = 100
)(
    input clk,
    input nreset,
    input start,
    input pause,
    input split_lap,
    input clear,
    output reg [7:0] minutes,
    output reg [7:0] seconds,
    output reg [7:0] centisec
);

   localparam MAX_TICK = FREQ_MHz * 10000; // For 100 Hz interval(10 ms)
   localparam WIDTH = $clog2(MAX_TICK);
   
   reg [WIDTH-1:0] tick_counter;
   reg running;
   reg split_active;

   // Internal BCD counting registers
   reg [3:0] c_ones, c_tens;
   reg [3:0] s_ones, s_tens;
   reg [3:0] m_ones, m_tens;

    // To catch split pulse
    reg split_r;
    wire split_pulse;
    always@(posedge clk or negedge nreset) begin
        if(!nreset) split_r <= 1'b0;
        else split_r <= split_lap;
    end
    assign split_pulse = split_lap && !split_r;

    //Operational state register
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            running <= 1'b0;
            split_active <= 1'b0;
        end
        else begin
            if(clear) begin
                running <= 1'b0;
                split_active <= 1'b0;
            end else begin
                if(start) running <= 1'b1;
                if(pause) running <= 1'b0;
                if(split_pulse) split_active <= ~split_active;
            end
        end
    end

    // Tick10ms signal generator
    wire tick_10ms;
    assign tick_10ms = (tick_counter == (MAX_TICK - 1));
    always @(posedge clk or negedge nreset) begin
        if(!nreset) tick_counter <= {WIDTH{1'b0}};
        else if(clear || !running) tick_counter <= {WIDTH{1'b0}};
        else begin
            if(tick_10ms) tick_counter <= {WIDTH{1'b0}};
            else tick_counter <= tick_counter + 1'b1;
        end
    end

    //Synchronous lookahead Enables for counters
    wire en_c_ones = tick_10ms && running;
    wire en_c_tens = en_c_ones && c_ones >= 4'd9;
    wire en_s_ones = en_c_tens && c_tens >= 4'd9;
    wire en_s_tens = en_s_ones && s_ones >= 4'd9;
    wire en_m_ones = en_s_tens && s_tens >= 4'd5;
    wire en_m_tens = en_m_ones && m_ones >= 4'd9;

    //Counter
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            c_ones <= 4'd0; c_tens <= 4'd0;
            s_ones <= 4'd0; s_tens <= 4'd0;
            m_ones <= 4'd0; m_tens <= 4'd0;
        end
        else if(clear) begin
            c_ones <= 4'd0; c_tens <= 4'd0;
            s_ones <= 4'd0; s_tens <= 4'd0;
            m_ones <= 4'd0; m_tens <= 4'd0;
        end
        else begin
            if(en_c_ones) begin
                if(c_ones >= 4'd9) c_ones <= 4'd0;
                else c_ones <= c_ones + 1;
            end
            if(en_c_tens) begin
                if(c_tens >= 4'd9) c_tens <= 4'd0;
                else c_tens <= c_tens + 1;
            end
            if(en_s_ones) begin
                if(s_ones >= 4'd9) s_ones <= 4'd0;
                else s_ones <= s_ones + 1;
            end
            if(en_s_tens) begin
                if(s_tens >= 4'd5) s_tens <= 4'd0;
                else s_tens <= s_tens + 1;
            end
            if(en_m_ones) begin
                if(m_ones >= 4'd9) m_ones <= 4'd0;
                else m_ones <= m_ones + 1;
            end
            if(en_m_tens) begin
                if(m_tens >= 4'd5) m_tens <= 4'd0;
                else m_tens <= m_tens + 1;
            end
        end
    end

    // Output Display(based on split lap)
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            centisec <= 8'd0;
            seconds <= 8'd0;
            minutes <= 8'd0;
        end
        else if(~split_active) begin
            centisec <= {c_tens, c_ones};
            seconds <= {s_tens, s_ones};
            minutes <= {m_tens, m_ones};
        end
    end
endmodule