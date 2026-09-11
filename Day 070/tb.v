`timescale 1ns / 1ps

module tb_direct_mapped_cache();

    parameter ADDR_WIDTH = 16;
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10;

    reg                   clk;
    reg                   nreset;

    // CPU Side
    reg                   cpu_req;
    reg                   cpu_wr;
    reg  [ADDR_WIDTH-1:0] cpu_addr;
    reg  [DATA_WIDTH-1:0] cpu_wdata;
    wire [DATA_WIDTH-1:0] cpu_rdata;
    wire                  cpu_ready;

    // Memory Side
    wire                  mem_req;
    wire                  mem_wr;
    wire [ADDR_WIDTH-1:0] mem_addr;
    wire [DATA_WIDTH-1:0] mem_wdata;
    reg  [DATA_WIDTH-1:0] mem_rdata;
    reg                   mem_ready;

    // Backing Store Model (256 words)
    reg  [DATA_WIDTH-1:0] memory [0:255];

    integer errors = 0;

    // Instantiate Cache Controller
    direct_mapped_cache #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .LINE_COUNT(8)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .cpu_req(cpu_req),
        .cpu_wr(cpu_wr),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready),
        .mem_req(mem_req),
        .mem_wr(mem_wr),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_ready(mem_ready)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    // Backing DRAM Responder Emulation
    always @(posedge clk or negedge nreset) begin
        if (!nreset) begin
            mem_ready <= 1'b0;
            mem_rdata <= 32'd0;
        end else begin
            mem_ready <= 1'b0;
            if (mem_req && !mem_ready) begin
                mem_ready <= 1'b1;
                if (mem_wr) begin
                    memory[mem_addr[7:0]] <= mem_wdata;
                    $display("[MEM LOG] WRITE BACK to 0x%04h | Data: 0x%08h", mem_addr, mem_wdata);
                end else begin
                    mem_rdata <= memory[mem_addr[7:0]];
                    $display("[MEM LOG] ALLOCATE READ from 0x%04h | Data: 0x%08h", mem_addr, memory[mem_addr[7:0]]);
                end
            end
        end
    end

    // Corrected Synchronous Transaction Task
    task cpu_access(
        input                   wr,
        input  [ADDR_WIDTH-1:0] addr,
        input  [DATA_WIDTH-1:0] wdata,
        input  [DATA_WIDTH-1:0] exp_rdata
    );
        begin
            @(negedge clk);
            cpu_req   = 1'b1;
            cpu_wr    = wr;
            cpu_addr  = addr;
            cpu_wdata = wdata;

            // Wait for handshake: unblock as soon as cpu_ready asserts
            wait (cpu_ready === 1'b1);
            #1; // Settle read data while still in S_COMP_TAG

            if (!wr) begin
                if (cpu_rdata !== exp_rdata) begin
                    $display("[FAIL] Read mismatch @ 0x%04h! Expected: 0x%08h, Got: 0x%08h", 
                             addr, exp_rdata, cpu_rdata);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] Read Verified @ 0x%04h | Data: 0x%08h", addr, cpu_rdata);
                end
            end else begin
                $display("[PASS] Write Committed @ 0x%04h | Data: 0x%08h", addr, wdata);
            end

            @(posedge clk); 
            #1;
            cpu_req = 1'b0;
            cpu_wr  = 1'b0;
        end
    endtask

    integer j;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_direct_mapped_cache);

        clk       = 0;
        nreset    = 0;
        cpu_req   = 0;
        cpu_wr    = 0;
        cpu_addr  = 0;
        cpu_wdata = 0;

        // Initialize Main Memory
        for (j = 0; j < 256; j = j + 1) begin
            memory[j] = 32'hA000_0000 + j;
        end

        // Reset Sequence
        #(CLK_PERIOD * 2);
        @(negedge clk);
        nreset = 1;
        #1;

        $display("\n=======================================================================================================");
        $display("                   DAY 70: DIRECT-MAPPED CACHE CONTROLLER VERIFICATION                                 ");
        $display("=======================================================================================================\n");

        // TEST 1: Cold Read Miss (Addr 0x0003: Index 3, Tag 0)
        $display("--- TEST 1: Compulsory Miss on Cold Cache (Addr 0x0003) ---");
        cpu_access(1'b0, 16'h0003, 32'h0, 32'hA000_0003);

        // TEST 2: Read Hit on Resident Line
        $display("\n--- TEST 2: Cache Hit on Resident Line (Addr 0x0003) ---");
        cpu_access(1'b0, 16'h0003, 32'h0, 32'hA000_0003);

        // TEST 3: Write Hit (Update cache & mark dirty)
        $display("\n--- TEST 3: Write Hit on Resident Line (Addr 0x0003 -> 0xDEADBEEF) ---");
        cpu_access(1'b1, 16'h0003, 32'hDEAD_BEEF, 32'h0);

        // TEST 3b: Read Dirty Line from Cache
        $display("\n--- TEST 3b: Reading modified dirty line from Cache ---");
        cpu_access(1'b0, 16'h0003, 32'h0, 32'hDEAD_BEEF);

        // TEST 4: Conflict Miss on Index 3 (Addr 0x0083 has same index 3, different tag)
        $display("\n--- TEST 4: Conflict Miss on Index 3 (Addr 0x0083) -> Triggers Write-Back ---");
        cpu_access(1'b0, 16'h0083, 32'h0, 32'hA000_0083);

        // TEST 5: Verify Write-Back Updated Backing Store
        $display("\n--- TEST 5: Checking Main Memory Audit for Addr 0x0003 ---");
        if (memory[16'h0003] === 32'hDEAD_BEEF) begin
            $display("[PASS] Memory coherency confirmed: Addr 0x0003 in DRAM holds 0xDEADBEEF!");
        end else begin
            $display("[FAIL] Memory mismatch! DRAM holds 0x%08h", memory[16'h0003]);
            errors = errors + 1;
        end

        #(CLK_PERIOD * 2);
        $display("\n=======================================================================================================");
        if (errors == 0)
            $display("   DAY 70 CACHE CONTROLLER VERIFIED SUCCESSFULLY WITH 0 ERRORS! (PASSED)");
        else
            $display("   VERIFICATION FAILED WITH %0d ERROR(S)!", errors);
        $display("=======================================================================================================\n");

        $finish;
    end

endmodule