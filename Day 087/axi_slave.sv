module axi_lite_slave #(
    parameter integer ADDR_WIDTH = 4,
    parameter integer DATA_WIDTH = 32
) (
    input  logic                    s_axi_aclk,
    input  logic                    s_axi_aresetn,

    // Write Address Channel (AW)
    input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,

    // Write Data Channel (W)
    input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,

    // Write Response Channel (B)
    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,

    // Read Address Channel (AR)
    input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,

    // Read Data Channel (R)
    output logic [DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready
);

    logic [31:0] slv_reg [0:3];
    logic        aw_done, w_done;
    logic [ADDR_WIDTH-1:0] latched_awaddr;
    logic [DATA_WIDTH-1:0] latched_wdata;
    logic [3:0]            latched_wstrb;

    assign s_axi_awready = ~aw_done && ~s_axi_bvalid;
    assign s_axi_wready  = ~w_done  && ~s_axi_bvalid;
    assign s_axi_bresp   = 2'b00;

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            aw_done        <= 1'b0;
            w_done         <= 1'b0;
            s_axi_bvalid   <= 1'b0;
            latched_awaddr <= '0;
            latched_wdata  <= '0;
            latched_wstrb  <= '0;
            for (int i = 0; i < 4; i++) slv_reg[i] <= 32'd0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                latched_awaddr <= s_axi_awaddr;
                aw_done        <= 1'b1;
            end

            if (s_axi_wvalid && s_axi_wready) begin
                latched_wdata <= s_axi_wdata;
                latched_wstrb <= s_axi_wstrb;
                w_done        <= 1'b1;
            end

            if ((aw_done || (s_axi_awvalid && s_axi_awready)) &&
                (w_done  || (s_axi_wvalid  && s_axi_wready))  && !s_axi_bvalid) begin
                
                logic [1:0]  reg_idx;
                logic [31:0] w_data_in;
                logic [3:0]  w_strb_in;

                reg_idx   = (aw_done) ? latched_awaddr[3:2] : s_axi_awaddr[3:2];
                w_data_in = (w_done)  ? latched_wdata       : s_axi_wdata;
                w_strb_in = (w_done)  ? latched_wstrb       : s_axi_wstrb;

                if (w_strb_in[0]) slv_reg[reg_idx][7:0]   <= w_data_in[7:0];
                if (w_strb_in[1]) slv_reg[reg_idx][15:8]  <= w_data_in[15:8];
                if (w_strb_in[2]) slv_reg[reg_idx][23:16] <= w_data_in[23:16];
                if (w_strb_in[3]) slv_reg[reg_idx][31:24] <= w_data_in[31:24];

                s_axi_bvalid <= 1'b1;
                aw_done      <= 1'b0;
                w_done       <= 1'b0;
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    assign s_axi_arready = ~s_axi_rvalid;
    assign s_axi_rresp   = 2'b00;

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata  <= 32'd0;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rdata  <= slv_reg[s_axi_araddr[3:2]];
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule