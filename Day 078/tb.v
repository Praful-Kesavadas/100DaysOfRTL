`timescale 1ns / 1ps

module tb_axi_lite_slave();

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 4;
    parameter CLK_PERIOD = 20; // 50 MHz = 20 ns

    reg                       aclk;
    reg                       aresetn;

    // Write Address
    reg  [ADDR_WIDTH-1:0]     s_axi_awaddr;
    reg  [2:0]                s_axi_awprot;
    reg                       s_axi_awvalid;
    wire                      s_axi_awready;

    // Write Data
    reg  [DATA_WIDTH-1:0]     s_axi_wdata;
    reg  [(DATA_WIDTH/8)-1:0] s_axi_wstrb;
    reg                       s_axi_wvalid;
    wire                      s_axi_wready;

    // Write Response
    wire [1:0]                s_axi_bresp;
    wire                      s_axi_bvalid;
    reg                       s_axi_bready;

    // Read Address
    reg  [ADDR_WIDTH-1:0]     s_axi_araddr;
    reg  [2:0]                s_axi_arprot;
    reg                       s_axi_arvalid;
    wire                      s_axi_arready;

    // Read Data
    wire [DATA_WIDTH-1:0]     s_axi_rdata;
    wire [1:0]                s_axi_rresp;
    wire                      s_axi_rvalid;
    reg                       s_axi_rready;

    // Internal Register Probes
    wire [DATA_WIDTH-1:0]     slv_reg0;
    wire [DATA_WIDTH-1:0]     slv_reg1;
    wire [DATA_WIDTH-1:0]     slv_reg2;
    wire [DATA_WIDTH-1:0]     slv_reg3;

    integer errors = 0;

    // Instantiate UUT
    axi_lite_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .slv_reg0_out(slv_reg0),
        .slv_reg1_out(slv_reg1),
        .slv_reg2_out(slv_reg2),
        .slv_reg3_out(slv_reg3)
    );

    // Clock Generation
    always #(CLK_PERIOD / 2) aclk = ~aclk;

    // -----------------------------------------------------------------
    // Master Bus Driving Tasks
    // -----------------------------------------------------------------
    // 1. Standard Synchronous Write (AW and W simultaneous)
    task axi_write(
        input [ADDR_WIDTH-1:0] addr,
        input [DATA_WIDTH-1:0] data,
        input [3:0]            strb
    );
        begin
            @(negedge aclk);
            s_axi_awaddr  = addr;
            s_axi_awvalid = 1'b1;
            s_axi_wdata   = data;
            s_axi_wstrb   = strb;
            s_axi_wvalid  = 1'b1;
            s_axi_bready  = 1'b1;

            // Wait for address and data handshakes
            fork
                begin
                    while (!(s_axi_awvalid && s_axi_awready)) @(posedge aclk);
                    @(negedge aclk);
                    s_axi_awvalid = 1'b0;
                end
                begin
                    while (!(s_axi_wvalid && s_axi_wready)) @(posedge aclk);
                    @(negedge aclk);
                    s_axi_wvalid = 1'b0;
                end
            join

            // Wait for response handshake
            while (!(s_axi_bvalid && s_axi_bready)) @(posedge aclk);
            @(negedge aclk);
            s_axi_bready = 1'b0;
        end
    endtask

    // 2. Out-of-Order Write: Address channel arrives 3 cycles BEFORE Data
    task axi_write_addr_first(
        input [ADDR_WIDTH-1:0] addr,
        input [DATA_WIDTH-1:0] data,
        input [3:0]            strb
    );
        begin
            @(negedge aclk);
            s_axi_awaddr  = addr;
            s_axi_awvalid = 1'b1;
            s_axi_wvalid  = 1'b0;
            s_axi_bready  = 1'b1;

            while (!(s_axi_awvalid && s_axi_awready)) @(posedge aclk);
            @(negedge aclk);
            s_axi_awvalid = 1'b0;

            // Delay before driving data
            repeat (3) @(posedge aclk);
            @(negedge aclk);
            s_axi_wdata  = data;
            s_axi_wstrb  = strb;
            s_axi_wvalid = 1'b1;

            while (!(s_axi_wvalid && s_axi_wready)) @(posedge aclk);
            @(negedge aclk);
            s_axi_wvalid = 1'b0;

            while (!(s_axi_bvalid && s_axi_bready)) @(posedge aclk);
            @(negedge aclk);
            s_axi_bready = 1'b0;
        end
    endtask

    // 3. Out-of-Order Write: Data channel arrives 3 cycles BEFORE Address
    task axi_write_data_first(
        input [ADDR_WIDTH-1:0] addr,
        input [DATA_WIDTH-1:0] data,
        input [3:0]            strb
    );
        begin
            @(negedge aclk);
            s_axi_wdata   = data;
            s_axi_wstrb   = strb;
            s_axi_wvalid  = 1'b1;
            s_axi_awvalid = 1'b0;
            s_axi_bready  = 1'b1;

            while (!(s_axi_wvalid && s_axi_wready)) @(posedge aclk);
            @(negedge aclk);
            s_axi_wvalid = 1'b0;

            // Delay before driving address
            repeat (3) @(posedge aclk);
            @(negedge aclk);
            s_axi_awaddr  = addr;
            s_axi_awvalid = 1'b1;

            while (!(s_axi_awvalid && s_axi_awready)) @(posedge aclk);
            @(negedge aclk);
            s_axi_awvalid = 1'b0;

            while (!(s_axi_bvalid && s_axi_bready)) @(posedge aclk);
            @(negedge aclk);
            s_axi_bready = 1'b0;
        end
    endtask

    // 4. Standard Read Task
    task axi_read(
        input  [ADDR_WIDTH-1:0] addr,
        input  [DATA_WIDTH-1:0] expected_data
    );
        begin
            @(negedge aclk);
            s_axi_araddr  = addr;
            s_axi_arvalid = 1'b1;
            s_axi_rready  = 1'b1;

            while (!(s_axi_arvalid && s_axi_arready)) @(posedge aclk);
            @(negedge aclk);
            s_axi_arvalid = 1'b0;

            while (!(s_axi_rvalid && s_axi_rready)) @(posedge aclk);
            if (s_axi_rdata !== expected_data) begin
                $display("[FAIL] Read Addr 0x%0h Mismatch! Got: 0x%08h, Expected: 0x%08h",
                         addr, s_axi_rdata, expected_data);
                errors = errors + 1;
            end else begin
                $display("[PASS] Read Addr 0x%0h Verified: 0x%08h", addr, s_axi_rdata);
            end

            @(negedge aclk);
            s_axi_rready = 1'b0;
        end
    endtask

    // -----------------------------------------------------------------
    // Test Sequencer
    // -----------------------------------------------------------------
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_axi_lite_slave);

        aclk          = 0;
        aresetn       = 0;
        s_axi_awaddr  = 0;
        s_axi_awprot  = 0;
        s_axi_awvalid = 0;
        s_axi_wdata   = 0;
        s_axi_wstrb   = 0;
        s_axi_wvalid  = 0;
        s_axi_bready  = 0;
        s_axi_araddr  = 0;
        s_axi_arprot  = 0;
        s_axi_arvalid = 0;
        s_axi_rready  = 0;

        #(CLK_PERIOD * 5);
        @(negedge aclk);
        aresetn = 1;
        #(CLK_PERIOD * 5);

        $display("\n=======================================================================================================");
        $display("                   DAY 78: AXI4-LITE SLAVE INTERFACE WRAPPER VERIFICATION                              ");
        $display("=======================================================================================================");

        // --- TEST 1: Simultaneous Write & Read Verification ---
        $display("\n--- TEST 1: Simultaneous Channel Write to All 4 Registers ---");
        axi_write(4'h0, 32'hA5A5A5A5, 4'b1111);
        axi_write(4'h4, 32'h5A5A5A5A, 4'b1111);
        axi_write(4'h8, 32'h12345678, 4'b1111);
        axi_write(4'hC, 32'h87654321, 4'b1111);

        axi_read(4'h0, 32'hA5A5A5A5);
        axi_read(4'h4, 32'h5A5A5A5A);
        axi_read(4'h8, 32'h12345678);
        axi_read(4'hC, 32'h87654321);

        // --- TEST 2: Out-of-Order Channel Arrival: AW Arrives First ---
        $display("\n--- TEST 2: Address Channel Arrives 3 Cycles Before Data Channel ---");
        axi_write_addr_first(4'h4, 32'hDEADBEEF, 4'b1111);
        axi_read(4'h4, 32'hDEADBEEF);

        // --- TEST 3: Out-of-Order Channel Arrival: W Arrives First ---
        $display("\n--- TEST 3: Data Channel Arrives 3 Cycles Before Address Channel ---");
        axi_write_data_first(4'h8, 32'hCAFEBABE, 4'b1111);
        axi_read(4'h8, 32'hCAFEBABE);

        // --- TEST 4: Byte Strobe Masking ---
        $display("\n--- TEST 4: Byte Strobe Masking (Overwrite Byte 1 with 0xAA) ---");
        // slv_reg1 holds 0xDEADBEEF. Overwrite byte 1 (bits [15:8]) with 0xAA -> 0xDEADAAEF
        axi_write(4'h4, 32'h0000AA00, 4'b0010);
        axi_read(4'h4, 32'hDEADAAEF);

        // --- TEST 5: Simultaneous Read and Write on the Exact Same Clock Cycle ---
        // --- TEST 5: Simultaneous Read and Write on the Exact Same Clock Cycle ---
        $display("\n--- TEST 5: Concurrent Read and Write Bus Operations ---");
        @(negedge aclk);
        // Fire Write to REG0 and Read from REG2 at the exact same instant
        s_axi_awaddr  = 4'h0;
        s_axi_awvalid = 1'b1;
        s_axi_wdata   = 32'h99999999;
        s_axi_wstrb   = 4'b1111;
        s_axi_wvalid  = 1'b1;
        s_axi_bready  = 1'b1;

        s_axi_araddr  = 4'h8;
        s_axi_arvalid = 1'b1;
        s_axi_rready  = 1'b1;

        // Wait for all address and data acceptance handshakes
        while (!(s_axi_awvalid && s_axi_awready && s_axi_wvalid && s_axi_wready && s_axi_arvalid && s_axi_arready))
            @(posedge aclk);

        @(negedge aclk);
        s_axi_awvalid = 1'b0;
        s_axi_wvalid  = 1'b0;
        s_axi_arvalid = 1'b0;

        // Drain B and R handshakes in parallel
        fork
            begin
                while (!(s_axi_bvalid && s_axi_bready)) @(posedge aclk);
                @(negedge aclk);
                s_axi_bready = 1'b0;
            end
            begin
                while (!(s_axi_rvalid && s_axi_rready)) @(posedge aclk);
                if (s_axi_rdata !== 32'hCAFEBABE) begin
                    $display("[FAIL] Concurrent Read Data Mismatch! Got: 0x%08h", s_axi_rdata);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] Concurrent Read & Write verified simultaneously!");
                end
                @(negedge aclk);
                s_axi_rready = 1'b0;
            end
        join

        // Verify the write to REG0 succeeded
        axi_read(4'h0, 32'h99999999);

        #(CLK_PERIOD * 10);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 78 AXI4-LITE SLAVE VERIFICATION SUCCESSFUL");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule