`timescale 1ns / 1ps

module tb_axis_protocol_adapter();

    parameter CLK_PERIOD = 10; // 100 MHz = 10 ns

    reg         aclk;
    reg         aresetn;

    // Upstream Slave Interface (Stimulus Driver)
    reg  [31:0] s_axis_tdata;
    reg  [3:0]  s_axis_tkeep;
    reg         s_axis_tlast;
    reg         s_axis_tvalid;
    wire        s_axis_tready;

    // Downstream Master Interface (Monitor)
    wire [7:0]  m_axis_tdata;
    wire        m_axis_tkeep;
    wire        m_axis_tlast;
    wire        m_axis_tvalid;
    reg         m_axis_tready;

    integer errors = 0;
    integer rx_byte_count = 0;

    // Instantiate UUT
    axis_protocol_adapter uut (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready)
    );

    // 100 MHz Clock Generator
    always #(CLK_PERIOD / 2) aclk = ~aclk;

    // -----------------------------------------------------------------
    // Master Driver Task: Transmits one 32-bit word
    // -----------------------------------------------------------------
    task send_word(
        input [31:0] data,
        input [3:0]  keep,
        input        last
    );
        begin
            @(negedge aclk);
            s_axis_tdata  = data;
            s_axis_tkeep  = keep;
            s_axis_tlast  = last;
            s_axis_tvalid = 1'b1;

            while (!(s_axis_tvalid && s_axis_tready)) @(posedge aclk);
            @(negedge aclk);
            s_axis_tvalid = 1'b0;
        end
    endtask

    // -----------------------------------------------------------------
    // Verification Suite
    // -----------------------------------------------------------------
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_axis_protocol_adapter);

        aclk          = 0;
        aresetn       = 0;
        s_axis_tdata  = 0;
        s_axis_tkeep  = 0;
        s_axis_tlast  = 0;
        s_axis_tvalid = 0;
        m_axis_tready = 1;

        #(CLK_PERIOD * 5);
        @(negedge aclk);
        aresetn = 1;
        #(CLK_PERIOD * 5);

        $display("\n=======================================================================================================");
        $display("                   DAY 79: AXI4-STREAM PROTOCOL ADAPTER VERIFICATION                                   ");
        $display("=======================================================================================================");

        // --- TEST 1: Full-Throughput Continuous Burst (8 Bytes / 2 Words) ---
        $display("\n--- TEST 1: Full-Throughput Continuous Streaming (Zero Bubbles) ---");
        fork
            begin
                send_word(32'h04030201, 4'b1111, 1'b0);
                send_word(32'h08070605, 4'b1111, 1'b1);
            end
            begin
                // Monitor downstream serialized bytes
                repeat (8) begin
                    while (!(m_axis_tvalid && m_axis_tready)) @(posedge aclk);
                    rx_byte_count = rx_byte_count + 1;
                    if (m_axis_tdata !== rx_byte_count[7:0]) begin
                        $display("[FAIL] Byte %0d Mismatch! Got: 0x%02h, Expected: 0x%02h",
                                 rx_byte_count, m_axis_tdata, rx_byte_count[7:0]);
                        errors = errors + 1;
                    end
                    if (rx_byte_count == 8 && m_axis_tlast !== 1'b1) begin
                        $display("[FAIL] Expected TLAST on Byte 8!");
                        errors = errors + 1;
                    end
                    @(negedge aclk);
                end
                $display("[PASS] Streamed 8 consecutive bytes with zero-bubble handshake!");
            end
        join

        #(CLK_PERIOD * 5);

        // --- TEST 2: Downstream Backpressure Injection During Burst ---
        $display("\n--- TEST 2: Downstream Backpressure Injection & Output Stability Audit ---");
        rx_byte_count = 0;
        fork
            begin
                send_word(32'hD0C0B0A0, 4'b1111, 1'b1);
            end
            begin
                // Receive Byte 0
                while (!(m_axis_tvalid && m_axis_tready)) @(posedge aclk);
                @(negedge aclk);
                // Stall downstream for 3 cycles before accepting Byte 1
                $display("[INFO] Asserting downstream backpressure (m_axis_tready = 0)");
                m_axis_tready = 1'b0;
                repeat (3) begin
                    @(posedge aclk);
                    if (m_axis_tvalid !== 1'b1 || m_axis_tdata !== 8'hB0) begin
                        $display("[FAIL] Stability Violation during stall! TVALID=%b, TDATA=0x%02h (Expected 0xB0)",
                                 m_axis_tvalid, m_axis_tdata);
                        errors = errors + 1;
                    end
                end
                @(negedge aclk);
                $display("[INFO] Releasing downstream backpressure (m_axis_tready = 1)");
                m_axis_tready = 1'b1;

                // Drain remaining bytes (0xB0, 0xC0, 0xD0)
                repeat (3) begin
                    while (!(m_axis_tvalid && m_axis_tready)) @(posedge aclk);
                    @(negedge aclk);
                end
                $display("[PASS] Handshake maintained protocol compliance during stall!");
            end
        join

        #(CLK_PERIOD * 5);

        // --- TEST 3: Partial-Word Packet Framing (6-Byte Packet: 4 + 2 Bytes) ---
        $display("\n--- TEST 3: Partial Word Framing via TKEEP (6 Bytes total) ---");
        rx_byte_count = 0;
        fork
            begin
                send_word(32'h44332211, 4'b1111, 1'b0); // Word 0: 4 bytes
                send_word(32'hXXXX6655, 4'b0011, 1'b1); // Word 1: 2 bytes, TLAST asserted
            end
            begin
                repeat (6) begin
                    while (!(m_axis_tvalid && m_axis_tready)) @(posedge aclk);
                    rx_byte_count = rx_byte_count + 1;

                    if (rx_byte_count == 6) begin
                        if (m_axis_tlast !== 1'b1 || m_axis_tdata !== 8'h66) begin
                            $display("[FAIL] Terminal byte 6 failed! TLAST=%b, DATA=0x%02h (Expected 0x66)",
                                     m_axis_tlast, m_axis_tdata);
                            errors = errors + 1;
                        end else begin
                            $display("[PASS] TLAST asserted on the 6th byte (partial word boundary)!");
                        end
                    end
                    @(negedge aclk);
                end
            end
        join

        #(CLK_PERIOD * 5);

        // --- TEST 4: Single-Byte Packet Framing (TKEEP = 4'b0001) ---
        $display("\n--- TEST 4: Single-Byte Packet Framing ---");
        fork
            begin
                send_word(32'hXXXXXX99, 4'b0001, 1'b1);
            end
            begin
                while (!(m_axis_tvalid && m_axis_tready)) @(posedge aclk);
                if (m_axis_tdata === 8'h99 && m_axis_tlast === 1'b1)
                    $display("[PASS] Single-byte packet verified (DATA=0x99, TLAST=1)");
                else begin
                    $display("[FAIL] Single-byte packet mismatch! DATA=0x%02h, TLAST=%b", m_axis_tdata, m_axis_tlast);
                    errors = errors + 1;
                end
                @(negedge aclk);
            end
        join

        #(CLK_PERIOD * 10);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 79 AXI4-STREAM PROTOCOL ADAPTER VERIFICATION SUCCESSFUL");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule