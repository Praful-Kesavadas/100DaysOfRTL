`include "uvm_macros.svh"
`define AXI_AW 4
`define AXI_DW 32

// Interface
interface axi_lite_if (input logic ACLK);
  logic                    ARESETn;
  logic [`AXI_AW-1:0]      AWADDR;  logic AWVALID; logic AWREADY;
  logic [`AXI_DW-1:0]      WDATA;   logic [`AXI_DW/8-1:0] WSTRB;
  logic                    WVALID;  logic WREADY;
  logic [1:0]              BRESP;   logic BVALID;  logic BREADY;
  logic [`AXI_AW-1:0]      ARADDR;  logic ARVALID; logic ARREADY;
  logic [`AXI_DW-1:0]      RDATA;   logic [1:0] RRESP;
  logic                    RVALID;  logic RREADY;

  clocking drv_cb @(posedge ACLK);
    default input #1step output #1;
    output AWADDR, AWVALID, WDATA, WSTRB, WVALID, BREADY, ARADDR, ARVALID, RREADY;
    input  AWREADY, WREADY, BRESP, BVALID, ARREADY, RDATA, RRESP, RVALID;
  endclocking

  clocking mon_cb @(posedge ACLK);
    default input #1step;
    input AWADDR, AWVALID, AWREADY, WDATA, WSTRB, WVALID, WREADY,
          BRESP, BVALID, BREADY, ARADDR, ARVALID, ARREADY,
          RDATA, RRESP, RVALID, RREADY;
  endclocking
endinterface

// Package
package axi_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Transaction
  typedef enum {ORD_SAME, ORD_AW_FIRST, ORD_W_FIRST} axi_order_e;
  // how a read relates to a write that is in flight when the read's AR handshakes
  typedef enum {REL_NONE, REL_DIFF_REG, REL_SAME_PRE, REL_SAME_POST} axi_rel_e;

  class axi_item extends uvm_sequence_item;
    rand bit                     is_write;
    rand bit [`AXI_AW-1:0]       addr;
    rand bit [`AXI_DW-1:0]       data;
    rand bit [`AXI_DW/8-1:0]     strb;
    // channel timing knobs (exercise AW/W ordering hazards)
    rand int unsigned            aw_delay, w_delay, b_delay;
    // results
    bit [`AXI_DW-1:0]            rdata;
    bit [1:0]                    resp;
    // observed by monitor (used for hazard coverage)
    axi_order_e                  order;   // which of AW/W handshook first
    int unsigned                 bp;      // cycles BVALID/RVALID waited for READY
    // timeline stamps (monitor cycle numbers) used by the scoreboard
    int unsigned                 t_first, t_commit, t_end;  // write: first/last AW|W handshake, B handshake
    int unsigned                 t_ar;                       // read : AR handshake
    // concurrent mode: a write item can carry a read that is launched in parallel
    bit                          pair;
    rand bit [`AXI_AW-1:0]       rd_addr;
    rand int unsigned            rd_start, rd_b_delay;
    rand bit                     same_reg;

    constraint c_addr  { addr[1:0] == 0; addr[`AXI_AW-1:2] inside {[0:3]}; }
    constraint c_delay { aw_delay inside {[0:4]}; w_delay inside {[0:4]};
                         b_delay  inside {[0:3]}; }
    constraint c_strb  { is_write -> strb dist {4'hF := 4, 4'h0 := 1, [4'h1:4'hE] :/ 6}; }
    constraint c_rd    { !is_write -> (strb == 0 && data == 0); }
    constraint c_rdaddr  { rd_addr[1:0] == 0; rd_addr[`AXI_AW-1:2] inside {[0:3]};
                           same_reg  -> rd_addr == addr;
                           !same_reg -> rd_addr != addr;
                           same_reg dist {1 := 2, 0 := 1}; }
    constraint c_rdtime  { rd_start inside {[0:6]}; rd_b_delay inside {[0:3]}; }
    constraint c_mix   { is_write dist {1 := 1, 0 := 1}; }      // 50/50 read/write
    constraint c_ord   { solve is_write before strb, data; }    // stop strb/data skewing the mix

    `uvm_object_utils_begin(axi_item)
      `uvm_field_int(is_write, UVM_ALL_ON)
      `uvm_field_int(addr,     UVM_ALL_ON | UVM_HEX)
      `uvm_field_int(data,     UVM_ALL_ON | UVM_HEX)
      `uvm_field_int(strb,     UVM_ALL_ON | UVM_BIN)
      `uvm_field_int(rdata,    UVM_ALL_ON | UVM_HEX)
      `uvm_field_int(resp,     UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "axi_item"); super.new(name); endfunction
  endclass

  // Sequences
  class axi_base_seq extends uvm_sequence #(axi_item);
    `uvm_object_utils(axi_base_seq)
    function new(string name = "axi_base_seq"); super.new(name); endfunction

    // delay args < 0 mean "leave random"
    task wr(bit [`AXI_AW-1:0] a_, bit [`AXI_DW/8-1:0] s_,
            int awd_ = -1, int wd_ = -1, int bd_ = -1);
      axi_item t = axi_item::type_id::create("wr_t");
      start_item(t);
      if (!t.randomize() with { is_write == 1; addr == a_; strb == s_;
                                (awd_ < 0) || (aw_delay == awd_);
                                (wd_  < 0) || (w_delay  == wd_);
                                (bd_  < 0) || (b_delay  == bd_); })
        `uvm_fatal("SEQ", "randomize failed (write)")
      finish_item(t);
    endtask

    task rd(bit [`AXI_AW-1:0] a_, int bd_ = -1);
      axi_item t = axi_item::type_id::create("rd_t");
      start_item(t);
      if (!t.randomize() with { is_write == 0; addr == a_;
                                (bd_ < 0) || (b_delay == bd_); })
        `uvm_fatal("SEQ", "randomize failed (read)")
      finish_item(t);
    endtask

    // write + read launched in parallel (independent channel groups)
    // args < 0 mean "leave random"; same_ = 1 forces same register, 0 forces different
    task pair_wr_rd(int awd_ = -1, int wd_ = -1, int rs_ = -1, int same_ = -1, int s_ = -1);
      axi_item t = axi_item::type_id::create("pair_t");
      t.pair = 1;
      start_item(t);
      if (!t.randomize() with { is_write == 1;
                                (awd_  < 0) || (aw_delay == awd_);
                                (wd_   < 0) || (w_delay  == wd_);
                                (rs_   < 0) || (rd_start == rs_);
                                (same_ < 0) || (same_reg == same_);
                                (s_    < 0) || (strb     == s_); })
        `uvm_fatal("SEQ", "randomize failed (pair)")
      finish_item(t);
    endtask

    task rnd();
      axi_item t = axi_item::type_id::create("rnd_t");
      start_item(t);
      if (!t.randomize()) `uvm_fatal("SEQ", "randomize failed (random)")
      finish_item(t);
    endtask
  endclass

  class axi_directed_seq extends axi_base_seq;
    `uvm_object_utils(axi_directed_seq)
    function new(string name = "axi_directed_seq"); super.new(name); endfunction
    task body();
      // full-word write then read back for every register
      for (int r = 0; r < 4; r++) begin
        wr(r*4, 4'hF);
        rd(r*4);
      end
      // each single-byte lane on reg0
      for (int b = 0; b < 4; b++) begin
        wr(0, 4'b1 << b);
        rd(0);
      end
    endtask
  endclass

  // Directed hazard sweep: every AW/W arrival order x B/R back-pressure x register
  class axi_hazard_seq extends axi_base_seq;
    `uvm_object_utils(axi_hazard_seq)
    int bd_list[3] = '{0, 1, 3};     // B/R back-pressure cycles to sweep
    function new(string name = "axi_hazard_seq"); super.new(name); endfunction
    task body();
      int awd, wd, bd;
      for (int ord = 0; ord < 3; ord++) begin
        case (ord)
          0: begin awd = 2; wd = 2; end   // AW and W together
          1: begin awd = 0; wd = 3; end   // AW first, W late  -> WR_WAIT_DATA
          2: begin awd = 3; wd = 0; end   // W first, AW late  -> WR_WAIT_ADDR
        endcase
        foreach (bd_list[k]) begin
          bd = bd_list[k];
          for (int r = 0; r < 4; r++) begin
            wr(r*4, 4'hF, awd, wd, bd);   // full-word write under this hazard
            rd(r*4, bd);                  // read back under B/R back-pressure
          end
        end
      end
    endtask
  endclass

  // Directed overlap sweep: slide the read's start across the write's lifetime so the
  // AR handshake lands before / during / after the write commit, same and different register.
  class axi_overlap_seq extends axi_base_seq;
    `uvm_object_utils(axi_overlap_seq)
    function new(string name = "axi_overlap_seq"); super.new(name); endfunction
    task body();
      for (int ord = 0; ord < 3; ord++) begin
        int awd, wd;
        case (ord)
          0: begin awd = 2; wd = 2; end
          1: begin awd = 0; wd = 3; end
          2: begin awd = 3; wd = 0; end
        endcase
        for (int k = 0; k < 7; k++) begin
          pair_wr_rd(awd, wd, k, 1, 4'hF);   // same register
          pair_wr_rd(awd, wd, k, 0, 4'hF);   // different register
        end
      end
    endtask
  endclass

  // Random concurrent traffic: every item is a write with a read running alongside it
  class axi_concurrent_seq extends axi_base_seq;
    `uvm_object_utils(axi_concurrent_seq)
    int unsigned n = 300;
    function new(string name = "axi_concurrent_seq"); super.new(name); endfunction
    task body();
      repeat (n) pair_wr_rd();
    endtask
  endclass

  class axi_random_seq extends axi_base_seq;
    `uvm_object_utils(axi_random_seq)
    int unsigned n = 1000;
    function new(string name = "axi_random_seq"); super.new(name); endfunction
    task body();
      repeat (n) rnd();
    endtask
  endclass

  // Driver
  class axi_driver extends uvm_driver #(axi_item);
    `uvm_component_utils(axi_driver)
    virtual axi_lite_if vif;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "vif", vif))
        `uvm_fatal("DRV", "vif not set")
    endfunction

    task run_phase(uvm_phase phase);
      vif.drv_cb.AWVALID <= 0; vif.drv_cb.WVALID <= 0; vif.drv_cb.BREADY <= 0;
      vif.drv_cb.ARVALID <= 0; vif.drv_cb.RREADY <= 0;
      wait (vif.ARESETn === 1'b1);
      repeat (2) @(vif.drv_cb);
      forever begin
        seq_item_port.get_next_item(req);
        if (req.is_write && req.pair) begin
          // independence of the two channel groups: write and read in flight together
          fork
            drive_write(req);
            drive_read(req.rd_addr, req.rd_start, req.rd_b_delay);
          join
        end
        else if (req.is_write) drive_write(req);
        else                   drive_read(req.addr, req.aw_delay, req.b_delay);
        seq_item_port.item_done();
      end
    endtask

    task drive_write(axi_item it);
      fork
        begin // AW channel
          repeat (it.aw_delay) @(vif.drv_cb);
          vif.drv_cb.AWADDR <= it.addr; vif.drv_cb.AWVALID <= 1;
          do @(vif.drv_cb); while (!vif.drv_cb.AWREADY);
          vif.drv_cb.AWVALID <= 0;
        end
        begin // W channel
          repeat (it.w_delay) @(vif.drv_cb);
          vif.drv_cb.WDATA <= it.data; vif.drv_cb.WSTRB <= it.strb; vif.drv_cb.WVALID <= 1;
          do @(vif.drv_cb); while (!vif.drv_cb.WREADY);
          vif.drv_cb.WVALID <= 0;
        end
      join
      repeat (it.b_delay) @(vif.drv_cb);
      vif.drv_cb.BREADY <= 1;
      do @(vif.drv_cb); while (!vif.drv_cb.BVALID);
      it.resp = vif.drv_cb.BRESP;
      vif.drv_cb.BREADY <= 0;
    endtask

    task drive_read(bit [`AXI_AW-1:0] a, int unsigned start_d, int unsigned rdy_d);
      repeat (start_d) @(vif.drv_cb);
      vif.drv_cb.ARADDR <= a; vif.drv_cb.ARVALID <= 1;
      do @(vif.drv_cb); while (!vif.drv_cb.ARREADY);
      vif.drv_cb.ARVALID <= 0;
      repeat (rdy_d) @(vif.drv_cb);
      vif.drv_cb.RREADY <= 1;
      do @(vif.drv_cb); while (!vif.drv_cb.RVALID);
      vif.drv_cb.RREADY <= 0;
    endtask
  endclass

  // Monitor
  class axi_monitor extends uvm_monitor;
    `uvm_component_utils(axi_monitor)
    virtual axi_lite_if vif;
    uvm_analysis_port #(axi_item) ap;
    bit [`AXI_AW-1:0]               aw_q[$], ar_q[$];
    bit [`AXI_DW+`AXI_DW/8-1:0]     w_q[$];
    int unsigned                    aw_c[$], w_c[$], ar_c[$];   // handshake cycle numbers
    int unsigned                    cyc;
    int unsigned                    b_start, r_start;
    bit                             b_pend, r_pend;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    function void build_phase(uvm_phase phase);
      ap = new("ap", this);
      if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "vif", vif))
        `uvm_fatal("MON", "vif not set")
    endfunction

    task run_phase(uvm_phase phase);
      axi_item it;
      bit [`AXI_DW+`AXI_DW/8-1:0] w;
      int unsigned awc, wc;
      wait (vif.ARESETn === 1'b1);
      forever begin
        @(vif.mon_cb);
        cyc++;
        if (vif.mon_cb.AWVALID && vif.mon_cb.AWREADY) begin
          aw_q.push_back(vif.mon_cb.AWADDR); aw_c.push_back(cyc);
        end
        if (vif.mon_cb.WVALID && vif.mon_cb.WREADY) begin
          w_q.push_back({vif.mon_cb.WSTRB, vif.mon_cb.WDATA}); w_c.push_back(cyc);
        end
        if (vif.mon_cb.ARVALID && vif.mon_cb.ARREADY) begin
          ar_q.push_back(vif.mon_cb.ARADDR); ar_c.push_back(cyc);
        end

        // back-pressure tracking: first cycle VALID seen -> handshake cycle
        if (vif.mon_cb.BVALID && !b_pend) begin b_pend = 1; b_start = cyc; end
        if (vif.mon_cb.RVALID && !r_pend) begin r_pend = 1; r_start = cyc; end

        if (vif.mon_cb.BVALID && vif.mon_cb.BREADY) begin
          if (aw_q.size() == 0 || w_q.size() == 0)
            `uvm_error("MON", "B response with no matching AW/W")
          else begin
            it = axi_item::type_id::create("wr_item");
            w = w_q.pop_front();
            awc = aw_c.pop_front(); wc = w_c.pop_front();
            it.is_write = 1; it.addr = aw_q.pop_front();
            it.data = w[`AXI_DW-1:0]; it.strb = w[`AXI_DW+`AXI_DW/8-1:`AXI_DW];
            it.resp = vif.mon_cb.BRESP;
            it.order = (awc < wc) ? ORD_AW_FIRST : (awc > wc) ? ORD_W_FIRST : ORD_SAME;
            it.bp = cyc - b_start;
            it.t_first  = (awc < wc) ? awc : wc;
            it.t_commit = (awc < wc) ? wc  : awc;
            it.t_end    = cyc;
            ap.write(it);
          end
          b_pend = 0;
        end
        if (vif.mon_cb.RVALID && vif.mon_cb.RREADY) begin
          if (ar_q.size() == 0)
            `uvm_error("MON", "R response with no matching AR")
          else begin
            it = axi_item::type_id::create("rd_item");
            it.is_write = 0; it.addr = ar_q.pop_front();
            it.rdata = vif.mon_cb.RDATA; it.resp = vif.mon_cb.RRESP;
            it.bp = cyc - r_start;
            it.t_ar = ar_c.pop_front();
            it.t_end = cyc;
            ap.write(it);
          end
          r_pend = 0;
        end
      end
    endtask
  endclass

  // Agent
  class axi_agent extends uvm_agent;
    `uvm_component_utils(axi_agent)
    axi_driver driver; axi_monitor monitor; uvm_sequencer #(axi_item) sqr;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      driver  = axi_driver::type_id::create("driver", this);
      monitor = axi_monitor::type_id::create("monitor", this);
      sqr     = uvm_sequencer#(axi_item)::type_id::create("sqr", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // Scoreboard
  class axi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi_scoreboard)
    uvm_analysis_imp #(axi_item, axi_scoreboard) imp;
    bit [`AXI_DW-1:0] model [4];     // reference registers, reset value 0
    axi_item wr_l[$], rd_l[$];       // collected transactions (each list is time-ordered)
    int wr_cnt, rd_cnt, errors;
    int n_none, n_diff, n_pre, n_post, amb_old, amb_new;
    axi_rel_e rel;

    covergroup cg_conc;
      cp_rel : coverpoint rel {
        bins no_write_inflight = {REL_NONE};
        bins diff_reg          = {REL_DIFF_REG};   // read overlaps a write to another register
        bins same_reg_pre      = {REL_SAME_PRE};   // AR lands at/before the write commit
        bins same_reg_post     = {REL_SAME_POST};  // AR lands after commit, before B response
      }
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      foreach (model[i]) model[i] = '0;
      cg_conc = new();
    endfunction
    function void build_phase(uvm_phase phase); imp = new("imp", this); endfunction

    // collect only; checking is done on the DUT's timeline in check_phase because with
    // concurrent traffic the order of monitor items is not the order of handshakes
    function void write(axi_item it);
      if (it.resp !== 2'b00) begin
        `uvm_error("SCB", $sformatf("Non-OKAY resp %0b on %s addr %0h",
                                    it.resp, it.is_write ? "WR" : "RD", it.addr))
        errors++;
      end
      if (it.is_write) begin wr_cnt++; wr_l.push_back(it); end
      else             begin rd_cnt++; rd_l.push_back(it); end
    endfunction

    function bit [`AXI_DW-1:0] apply(bit [`AXI_DW-1:0] cur, axi_item w);
      bit [`AXI_DW-1:0] v = cur;
      for (int b = 0; b < `AXI_DW/8; b++)
        if (w.strb[b]) v[8*b +: 8] = w.data[8*b +: 8];
      return v;
    endfunction

    // index of the write in flight (first AW/W handshake .. B handshake) at the read's AR cycle
    function int find_inflight(axi_item r);
      foreach (wr_l[k])
        if (r.t_ar >= wr_l[k].t_first && r.t_ar <= wr_l[k].t_end) return k;
      return -1;
    endfunction

    // Replay writes (at their commit cycle) and reads (at their AR cycle) in time order.
    // A write commit and a read AR in the same cycle -> the read sees the OLD value.
    // A read overlapping a same-register write before it commits may legally see old or new.
    function void check_phase(uvm_phase phase);
      int i = 0, j = 0, k, idx;
      axi_item w, r;
      bit [`AXI_DW-1:0] exp_v, new_v;
      while (i < wr_l.size() || j < rd_l.size()) begin
        if (j < rd_l.size() && (i >= wr_l.size() || rd_l[j].t_ar <= wr_l[i].t_commit)) begin
          r = rd_l[j++];
          idx = r.addr[`AXI_AW-1:2];
          exp_v = model[idx];
          k = find_inflight(r);
          if (k < 0) rel = REL_NONE;
          else begin
            w = wr_l[k];
            if (w.addr != r.addr)         rel = REL_DIFF_REG;
            else if (r.t_ar <= w.t_commit) rel = REL_SAME_PRE;
            else                           rel = REL_SAME_POST;
          end
          case (rel)
            REL_NONE:      n_none++;
            REL_DIFF_REG:  n_diff++;
            REL_SAME_PRE:  n_pre++;
            REL_SAME_POST: n_post++;
          endcase
          if (rel == REL_SAME_PRE) begin
            new_v = apply(exp_v, w);
            if      (r.rdata === exp_v) amb_old++;
            else if (r.rdata === new_v) amb_new++;
            else begin
              `uvm_error("SCB", $sformatf("MISMATCH reg%0d (overlap): old=%08h new=%08h got=%08h",
                                          idx, exp_v, new_v, r.rdata))
              errors++;
            end
          end
          else if (r.rdata !== exp_v) begin
            `uvm_error("SCB", $sformatf("MISMATCH reg%0d: exp=%08h got=%08h (ar@%0d)",
                                        idx, exp_v, r.rdata, r.t_ar))
            errors++;
          end
          cg_conc.sample();
        end
        else begin
          w = wr_l[i++];
          idx = w.addr[`AXI_AW-1:2];
          model[idx] = apply(model[idx], w);
        end
      end
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SCB", $sformatf("RESULT: %0d writes | %0d reads | %0d mismatches -> %s",
                wr_cnt, rd_cnt, errors, errors == 0 ? "PASS" : "FAIL"), UVM_NONE)
      `uvm_info("SCB", $sformatf("Concurrency: reads with no write in flight=%0d | write in flight to other reg=%0d | same reg before commit=%0d | same reg after commit=%0d",
                n_none, n_diff, n_pre, n_post), UVM_NONE)
      `uvm_info("SCB", $sformatf("Same-register overlap before commit: read returned old=%0d new=%0d",
                amb_old, amb_new), UVM_NONE)
      `uvm_info("SCB", $sformatf("Concurrency coverage = %0.2f%%", cg_conc.get_coverage()), UVM_NONE)
    endfunction
  endclass

  // --------------------------------------------------------------- coverage
  class axi_coverage extends uvm_subscriber #(axi_item);
    `uvm_component_utils(axi_coverage)
    axi_item it;
    bit                  have_wr, raw;          // read-after-write to same register
    bit [`AXI_AW-1:0]    last_wr;
    int n_same, n_awf, n_wf;                    // observed arrival-order counts

    covergroup cg;
      cp_op   : coverpoint it.is_write { bins read = {0}; bins write = {1}; }
      cp_reg  : coverpoint it.addr[`AXI_AW-1:2] { bins r[] = {[0:3]}; }
      cp_strb : coverpoint it.strb iff (it.is_write) {
                  bins none = {0}; bins full = {4'hF}; bins single[] = {1,2,4,8};
                  bins partial = default; }
      // AW/W arrival hazard (drives WR_IDLE / WR_WAIT_DATA / WR_WAIT_ADDR)
      cp_order : coverpoint it.order iff (it.is_write) {
                  bins same     = {ORD_SAME};
                  bins aw_first = {ORD_AW_FIRST};
                  bins w_first  = {ORD_W_FIRST}; }
      // B / R channel back-pressure (VALID held waiting for READY)
      cp_bp_wr : coverpoint it.bp iff (it.is_write)  { bins none = {0}; bins short = {[1:2]}; bins long = {[3:$]}; }
      cp_bp_rd : coverpoint it.bp iff (!it.is_write) { bins none = {0}; bins short = {[1:2]}; bins long = {[3:$]}; }
      cp_raw   : coverpoint raw   iff (!it.is_write) { bins raw_hit = {1}; bins raw_miss = {0}; }

      cx_op_reg     : cross cp_op, cp_reg;
      cx_reg_strb   : cross cp_reg, cp_strb iff (it.is_write);
      cx_order_bp   : cross cp_order, cp_bp_wr iff (it.is_write);
      cx_order_reg  : cross cp_order, cp_reg   iff (it.is_write);
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent); cg = new();
    endfunction

    function void write(axi_item t);
      it = t;
      raw = (!t.is_write && have_wr && t.addr == last_wr);
      if (t.is_write) begin
        have_wr = 1; last_wr = t.addr;
        case (t.order)
          ORD_SAME:     n_same++;
          ORD_AW_FIRST: n_awf++;
          ORD_W_FIRST:  n_wf++;
        endcase
      end
      cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("COV", $sformatf("Write arrival order: AW-first=%0d | W-first=%0d | same-cycle=%0d",
                                 n_awf, n_wf, n_same), UVM_NONE)
      `uvm_info("COV", $sformatf("Functional coverage = %0.2f%%", cg.get_coverage()), UVM_NONE)
    endfunction
  endclass

  // -------------------------------------------------------------------- env
  class axi_env extends uvm_env;
    `uvm_component_utils(axi_env)
    axi_agent agent; axi_scoreboard scb; axi_coverage cov;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      agent = axi_agent::type_id::create("agent", this);
      scb   = axi_scoreboard::type_id::create("scb", this);
      cov   = axi_coverage::type_id::create("cov", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      agent.monitor.ap.connect(scb.imp);
      agent.monitor.ap.connect(cov.analysis_export);
    endfunction
  endclass

  // ------------------------------------------------------------------- test
  class axi_test extends uvm_test;
    `uvm_component_utils(axi_test)
    axi_env env;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      env = axi_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
      axi_directed_seq dseq = axi_directed_seq::type_id::create("dseq");
      axi_hazard_seq   hseq = axi_hazard_seq::type_id::create("hseq");
      axi_overlap_seq    oseq = axi_overlap_seq::type_id::create("oseq");
      axi_concurrent_seq cseq = axi_concurrent_seq::type_id::create("cseq");
      axi_random_seq   rseq = axi_random_seq::type_id::create("rseq");
      phase.raise_objection(this);
      dseq.start(env.agent.sqr);
      hseq.start(env.agent.sqr);
      oseq.start(env.agent.sqr);       // directed read/write overlap sweep
      cseq.n = 300;
      cseq.start(env.agent.sqr);       // random concurrent read+write traffic
      rseq.n = 1000;
      rseq.start(env.agent.sqr);
      #200ns;                     // drain
      phase.drop_objection(this);
    endtask
  endclass
endpackage

// --------------------------------------------------------------------- top
module tb_top;
  import uvm_pkg::*;
  import axi_pkg::*;

  logic ACLK = 0;
  always #5 ACLK = ~ACLK;

  axi_lite_if vif (ACLK);

  initial begin
    vif.ARESETn = 0;
    repeat (5) @(posedge ACLK);
    vif.ARESETn = 1;
  end

  axi_lite_slave #(.DATA_WIDTH(`AXI_DW), .ADDR_WIDTH(`AXI_AW)) dut (
    .aclk(ACLK),            .aresetn(vif.ARESETn),
    .s_axi_awaddr(vif.AWADDR), .s_axi_awprot(3'b000),
    .s_axi_awvalid(vif.AWVALID), .s_axi_awready(vif.AWREADY),
    .s_axi_wdata(vif.WDATA),   .s_axi_wstrb(vif.WSTRB),
    .s_axi_wvalid(vif.WVALID), .s_axi_wready(vif.WREADY),
    .s_axi_bresp(vif.BRESP),   .s_axi_bvalid(vif.BVALID), .s_axi_bready(vif.BREADY),
    .s_axi_araddr(vif.ARADDR), .s_axi_arprot(3'b000),
    .s_axi_arvalid(vif.ARVALID), .s_axi_arready(vif.ARREADY),
    .s_axi_rdata(vif.RDATA),   .s_axi_rresp(vif.RRESP),
    .s_axi_rvalid(vif.RVALID), .s_axi_rready(vif.RREADY),
    .slv_reg0_out(), .slv_reg1_out(), .slv_reg2_out(), .slv_reg3_out()
  );

  initial begin
    uvm_config_db#(virtual axi_lite_if)::set(null, "*", "vif", vif);
    run_test("axi_test");
  end

  initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tb_top);
  end
endmodule