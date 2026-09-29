interface axi_lite_if (input logic aclk, input logic aresetn);
    logic [3:0]  awaddr;
    logic        awvalid;
    logic        awready;

    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wvalid;
    logic        wready;

    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;

    logic [3:0]  araddr;
    logic        arvalid;
    logic        arready;

    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready;
endinterface

class axi_transaction;
    typedef enum { WRITE, READ } op_type_e;

    rand op_type_e  op;
    rand bit [3:0]  addr;
    rand bit [31:0] data;
    rand bit [3:0]  wstrb;

    bit [31:0]      rdata;
    bit [1:0]       resp;

    constraint c_align {
        addr[1:0] == 2'b00;
        addr inside {4'h0, 4'h4, 4'h8, 4'hC};
    }

    constraint c_wstrb {
        wstrb != 4'b0000;
    }

    constraint c_op_dist {
        op dist { WRITE := 50, READ := 50 };
    }
endclass

class generator;
    mailbox #(axi_transaction) gen2drv;
    int num_transactions;

    function new(mailbox #(axi_transaction) gen2drv, int num_transactions);
        this.gen2drv          = gen2drv;
        this.num_transactions = num_transactions;
    endfunction

    task run();
        for (int i = 0; i < num_transactions; i++) begin
            axi_transaction tr = new();
            // Checking (== 0) fixes the %Warning-WIDTHTRUNC in Verilator
            if (tr.randomize() == 0) begin
                $fatal(1, "[GEN] Randomization failed!");
            end
            gen2drv.put(tr);
        end
    endtask
endclass

class driver;
    virtual axi_lite_if vif;
    mailbox #(axi_transaction) gen2drv;

    function new(virtual axi_lite_if vif, mailbox #(axi_transaction) gen2drv);
        this.vif     = vif;
        this.gen2drv = gen2drv;
    endfunction

    task run();
        vif.awvalid <= 1'b0;
        vif.awaddr  <= '0;
        vif.wvalid  <= 1'b0;
        vif.wdata   <= '0;
        vif.wstrb   <= '0;
        vif.bready  <= 1'b0;
        vif.arvalid <= 1'b0;
        vif.araddr  <= '0;
        vif.rready  <= 1'b0;

        @(posedge vif.aresetn);

        forever begin
            axi_transaction tr;
            gen2drv.get(tr);

            if (tr.op == axi_transaction::WRITE) begin
                fork
                    begin
                        repeat ($urandom_range(0, 2)) @(posedge vif.aclk);
                        vif.awaddr  <= tr.addr;
                        vif.awvalid <= 1'b1;
                        do @(posedge vif.aclk); while (!vif.awready);
                        vif.awvalid <= 1'b0;
                    end
                    begin
                        repeat ($urandom_range(0, 2)) @(posedge vif.aclk);
                        vif.wdata   <= tr.data;
                        vif.wstrb   <= tr.wstrb;
                        vif.wvalid  <= 1'b1;
                        do @(posedge vif.aclk); while (!vif.wready);
                        vif.wvalid  <= 1'b0;
                    end
                join

                repeat ($urandom_range(0, 2)) @(posedge vif.aclk);
                vif.bready <= 1'b1;
                do @(posedge vif.aclk); while (!vif.bvalid);
                vif.bready <= 1'b0;

            end else begin
                repeat ($urandom_range(0, 2)) @(posedge vif.aclk);
                vif.araddr  <= tr.addr;
                vif.arvalid <= 1'b1;
                do @(posedge vif.aclk); while (!vif.arready);
                vif.arvalid <= 1'b0;

                repeat ($urandom_range(0, 2)) @(posedge vif.aclk);
                vif.rready <= 1'b1;
                do @(posedge vif.aclk); while (!vif.rvalid);
                vif.rready <= 1'b0;
            end
        end
    endtask
endclass

class monitor;
    virtual axi_lite_if vif;
    mailbox #(axi_transaction) mon2scb;

    function new(virtual axi_lite_if vif, mailbox #(axi_transaction) mon2scb);
        this.vif     = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        fork
            forever begin
                logic [3:0]  sampled_addr;
                logic [31:0] sampled_data;
                logic [3:0]  sampled_strb;

                fork
                    begin
                        do @(posedge vif.aclk); while (!(vif.awvalid && vif.awready));
                        sampled_addr = vif.awaddr;
                    end
                    begin
                        do @(posedge vif.aclk); while (!(vif.wvalid && vif.wready));
                        sampled_data = vif.wdata;
                        sampled_strb = vif.wstrb;
                    end
                join

                do @(posedge vif.aclk); while (!(vif.bvalid && vif.bready));

                begin
                    axi_transaction tr = new();
                    tr.op    = axi_transaction::WRITE;
                    tr.addr  = sampled_addr;
                    tr.data  = sampled_data;
                    tr.wstrb = sampled_strb;
                    tr.resp  = vif.bresp;
                    mon2scb.put(tr);
                end
            end

            forever begin
                logic [3:0] sampled_addr;

                do @(posedge vif.aclk); while (!(vif.arvalid && vif.arready));
                sampled_addr = vif.araddr;

                do @(posedge vif.aclk); while (!(vif.rvalid && vif.rready));

                begin
                    axi_transaction tr = new();
                    tr.op    = axi_transaction::READ;
                    tr.addr  = sampled_addr;
                    tr.rdata = vif.rdata;
                    tr.resp  = vif.rresp;
                    mon2scb.put(tr);
                end
            end
        join
    endtask
endclass

class scoreboard;
    mailbox #(axi_transaction) mon2scb;
    logic [31:0] ref_model [0:3];
    int write_count = 0;
    int read_count  = 0;
    int error_count = 0;

    function new(mailbox #(axi_transaction) mon2scb);
        this.mon2scb = mon2scb;
        for (int i = 0; i < 4; i++) ref_model[i] = 32'd0;
    endfunction

    task run();
        forever begin
            axi_transaction tr;
            mon2scb.get(tr);

            if (tr.op == axi_transaction::WRITE) begin
                logic [1:0] idx = tr.addr[3:2];
                if (tr.wstrb[0]) ref_model[idx][7:0]   = tr.data[7:0];
                if (tr.wstrb[1]) ref_model[idx][15:8]  = tr.data[15:8];
                if (tr.wstrb[2]) ref_model[idx][23:16] = tr.data[23:16];
                if (tr.wstrb[3]) ref_model[idx][31:24] = tr.data[31:24];
                write_count++;
            end else begin
                logic [1:0] idx = tr.addr[3:2];
                logic [31:0] expected_data = ref_model[idx];

                if (tr.rdata !== expected_data) begin
                    $display("[FAIL] Read Mismatch @ 0x%0h: Expected=0x%08h, Got=0x%08h",
                             tr.addr, expected_data, tr.rdata);
                    error_count++;
                end
                read_count++;
            end
        end
    endtask
endclass

module tb_axi_lite_random;

    localparam NUM_TRANSACTIONS = 2000;

    logic aclk = 0;
    logic aresetn;
    always #5 aclk = ~aclk;

    axi_lite_if vif(aclk, aresetn);

    axi_lite_slave #(
        .ADDR_WIDTH(4),
        .DATA_WIDTH(32)
    ) dut (
        .s_axi_aclk   (vif.aclk),
        .s_axi_aresetn(vif.aresetn),
        .s_axi_awaddr (vif.awaddr),
        .s_axi_awvalid(vif.awvalid),
        .s_axi_awready(vif.awready),
        .s_axi_wdata  (vif.wdata),
        .s_axi_wstrb  (vif.wstrb),
        .s_axi_wvalid (vif.wvalid),
        .s_axi_wready (vif.wready),
        .s_axi_bresp  (vif.bresp),
        .s_axi_bvalid (vif.bvalid),
        .s_axi_bready (vif.bready),
        .s_axi_araddr (vif.araddr),
        .s_axi_arvalid(vif.arvalid),
        .s_axi_arready(vif.arready),
        .s_axi_rdata  (vif.rdata),
        .s_axi_rresp  (vif.rresp),
        .s_axi_rvalid (vif.rvalid),
        .s_axi_rready (vif.rready)
    );

    mailbox #(axi_transaction) gen2drv = new();
    mailbox #(axi_transaction) mon2scb = new();

    generator  gen = new(gen2drv, NUM_TRANSACTIONS);
    driver     drv = new(vif, gen2drv);
    monitor    mon = new(vif, mon2scb);
    scoreboard scb = new(mon2scb);

    initial begin
        aresetn = 0;
        #25;
        @(negedge aclk);
        aresetn = 1;

        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_any

        wait ((scb.write_count + scb.read_count) >= NUM_TRANSACTIONS);
        #100;

        $display("\n==================================================================================================");
        $display("          DAY 87: AXI-LITE CONSTRAINED-RANDOM TESTBENCH & SCOREBOARD SUMMARY                      ");
        $display("==================================================================================================");
        $display("  Total Completed Transactions : %0d (Writes: %0d | Reads: %0d)",
                 scb.write_count + scb.read_count, scb.write_count, scb.read_count);
        $display("  Scoreboard Data Mismatches   : %0d", scb.error_count);
        $display("==================================================================================================");

        if (scb.error_count == 0)
            $display("  >>> ALL %0d TRANSACTIONS MATCHED GOLDEN MODEL: TEST PASSED! <<<\n", NUM_TRANSACTIONS);
        else
            $display("  >>> TEST FAILED WITH %0d ERROR(S) <<<\n", scb.error_count);

        $finish;
    end

endmodule