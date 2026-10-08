module axi_lite_slave #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4
)(
    input aclk, aresetn,

    //Write Address channel
    input [ADDR_WIDTH-1:0] s_axi_awaddr,
    input [2:0] s_axi_awprot,
    input s_axi_awvalid,
    output reg s_axi_awready,

    //Write Data Channel
    input [DATA_WIDTH-1:0] s_axi_wdata,
    input [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input s_axi_wvalid,
    output reg s_axi_wready,

    //Write Response Channel
    output reg [1:0] s_axi_bresp,
    output reg s_axi_bvalid,
    input s_axi_bready,

    //Read Address Channel
    input [ADDR_WIDTH-1:0] s_axi_araddr,
    input [2:0] s_axi_arprot,
    input s_axi_arvalid,
    output reg s_axi_arready,

    //Read Data Channel
    output reg [DATA_WIDTH-1:0] s_axi_rdata,
    output reg [1:0] s_axi_rresp,
    output reg s_axi_rvalid,
    input s_axi_rready,

    //User Register Bank interface
    output [DATA_WIDTH-1:0] slv_reg0_out, slv_reg1_out, slv_reg2_out, slv_reg3_out
);

    //Internal Memory-mapped registers
    reg [DATA_WIDTH-1:0] slv_reg0;  //Offset 0x00: Control
    reg [DATA_WIDTH-1:0] slv_reg1;  //Offset 0x04: Status
    reg [DATA_WIDTH-1:0] slv_reg2;  //Offset 0x08: Data 0
    reg [DATA_WIDTH-1:0] slv_reg3;  //Offset 0x0C: Data 1

    assign slv_reg0_out = slv_reg0;
    assign slv_reg1_out = slv_reg1;
    assign slv_reg2_out = slv_reg2;
    assign slv_reg3_out = slv_reg3;

    //Response Encodings(AMBA AXI Standard)
    localparam RESP_OKAY = 2'b00;
    localparam RESP_SLVERR = 2'b10;

    //Buffer Registers for write channel decoupling
    reg [ADDR_WIDTH-1:0] latched_awaddr;
    reg [DATA_WIDTH-1:0] latched_wdata;
    reg [(DATA_WIDTH/8)-1:0] latched_wstrb;

    //Write FSM
    localparam WR_IDLE = 2'd0;  //Ready for AW/W
    localparam WR_WAIT_DATA = 2'd1; //AW captured, waiting for W
    localparam WR_WAIT_ADDR = 2'd2; //W captured, waiting for AW
    localparam WR_RESP = 2'd3;

    reg [1:0] wr_state, wr_next_state;

    //Next State Logic for WRITE
    always@(*) begin
        wr_next_state = wr_state;

        case(wr_state)
            WR_IDLE: begin
                if(s_axi_awvalid && s_axi_awready && s_axi_wvalid && s_axi_wready)
                    wr_next_state = WR_RESP;
                else if(s_axi_awvalid && s_axi_awready) 
                    wr_next_state = WR_WAIT_DATA;
                else if(s_axi_wvalid && s_axi_wready)
                    wr_next_state = WR_WAIT_ADDR;
            end

            WR_WAIT_ADDR: begin
                if(s_axi_awvalid && s_axi_awready)
                    wr_next_state = WR_RESP;
            end

            WR_WAIT_DATA: begin
                if(s_axi_wvalid && s_axi_wready)
                    wr_next_state = WR_RESP;
            end 

            WR_RESP: begin
                if(s_axi_bvalid && s_axi_bready)
                    wr_next_state = WR_IDLE;
            end

            default: wr_next_state = WR_IDLE;
        endcase
    end

    //Write State Transition
    always@(posedge aclk or negedge aresetn) begin
        if(!aresetn) wr_state <= WR_IDLE;
        else wr_state <= wr_next_state;
    end 

    //Write path
    integer byte_idx;
    wire write_commit = (wr_state == WR_IDLE && s_axi_awvalid && s_axi_awready && s_axi_wvalid && s_axi_wready) ||
                        (wr_state == WR_WAIT_ADDR && s_axi_awvalid && s_axi_awready) ||
                        (wr_state == WR_WAIT_DATA && s_axi_wvalid && s_axi_wready);
    
    //If waiting state, use the latched value
    wire [ADDR_WIDTH-1:0] active_waddr = (wr_state == WR_WAIT_DATA) ? latched_awaddr : s_axi_awaddr;
    wire [DATA_WIDTH-1:0] active_wdata = (wr_state == WR_WAIT_ADDR) ? latched_wdata : s_axi_wdata;
    wire [(DATA_WIDTH/8)-1:0] active_wstrb = (wr_state == WR_WAIT_ADDR) ? latched_wstrb : s_axi_wstrb; 

    always@(posedge aclk or negedge aresetn) begin
        if(!aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= RESP_OKAY;
            latched_awaddr <= 0;
            latched_wdata <= 0;
            latched_wstrb <= 0;
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            slv_reg2 <= 0;
            slv_reg3 <= 0;
        end 
        else begin
            //Default Handshakes
            case(wr_next_state)
                WR_IDLE: begin
                    s_axi_awready <= 1'b1;
                    s_axi_wready <= 1'b1;
                    s_axi_bvalid <= 1'b0;
                end

                WR_WAIT_DATA: begin
                    s_axi_awready <=  1'b0;
                    s_axi_wready <= 1'b1;
                    s_axi_bvalid <= 1'b0;
                    if(s_axi_awvalid && s_axi_awready) 
                        latched_awaddr <= s_axi_awaddr;
                end

                WR_WAIT_ADDR: begin
                    s_axi_awready <= 1'b1;
                    s_axi_wready <= 1'b0;
                    s_axi_bvalid <= 1'b0;
                    if(s_axi_wready && s_axi_wvalid) begin
                        latched_wdata <= s_axi_wdata;
                        latched_wstrb <= s_axi_wstrb;
                    end
                end

                WR_RESP: begin
                    s_axi_awready <= 1'b0;
                    s_axi_wready <= 1'b0;
                    s_axi_bvalid <= 1'b1;
                    s_axi_bresp <= RESP_OKAY;
                end
                default: ;
            endcase

            //Register Write commit with byte strobe evaluation
            if(write_commit) begin
                case(active_waddr[3:2])
                    2'b00: begin
                        for(byte_idx = 0; byte_idx < (DATA_WIDTH/8); byte_idx = byte_idx + 1)begin
                            if(active_wstrb[byte_idx])
                                slv_reg0[byte_idx*8 +: 8] <= active_wdata[(byte_idx*8) +: 8];
                        end
                    end
                    2'b01: begin
                        for(byte_idx = 0; byte_idx < (DATA_WIDTH/8); byte_idx = byte_idx + 1)begin
                            if(active_wstrb[byte_idx])
                                slv_reg1[byte_idx*8 +: 8] <= active_wdata[(byte_idx*8) +: 8];
                        end
                    end
                    2'b10: begin
                        for(byte_idx = 0; byte_idx < (DATA_WIDTH/8); byte_idx = byte_idx + 1)begin
                            if(active_wstrb[byte_idx])
                                slv_reg2[byte_idx*8 +: 8] <= active_wdata[(byte_idx*8) +: 8];
                        end
                    end  
                    2'b11: begin
                        for(byte_idx = 0; byte_idx < (DATA_WIDTH/8); byte_idx = byte_idx + 1)begin
                            if(active_wstrb[byte_idx])
                                slv_reg3[byte_idx*8 +: 8] <= active_wdata[(byte_idx*8) +: 8];
                        end
                    end 
                    default: ;
                endcase
            end
        end
    end

    //Read FSM
    localparam RD_IDLE = 1'b0;  //Ready for AR
    localparam RD_RESP = 1'b1;  //RDATA valid, awaiting RREADY

    reg rd_state, rd_next_state;

    //Next State Logic(READ)
    always@(*) begin
        rd_next_state = rd_state;
        case(rd_state) 
            RD_IDLE: begin
                if(s_axi_arready && s_axi_arvalid) 
                    rd_next_state = RD_RESP;
            end
            RD_RESP: begin
                if(s_axi_rready && s_axi_rvalid)
                    rd_next_state = RD_IDLE;
            end
            default: rd_next_state = RD_IDLE;
        endcase 
    end

    //READ State transition
    always@(posedge aclk or negedge aresetn) begin
        if(!aresetn) rd_state <= RD_IDLE;
        else rd_state <= rd_next_state;
    end

    //Register Updates
    always@(posedge aclk or negedge aresetn) begin
        if(!aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid <= 1'b0;
            s_axi_rdata <= 0;
            s_axi_rresp <= RESP_OKAY;
        end
        else begin
            case(rd_next_state)
                RD_IDLE: begin
                    s_axi_arready <= 1'b1;
                    s_axi_rvalid <= 1'b0;
                end
                RD_RESP: begin
                    s_axi_arready <= 1'b0;
                    s_axi_rvalid <= 1'b1;
                    s_axi_rresp <= RESP_OKAY;

                    if (rd_state == RD_IDLE) begin
                        case(s_axi_araddr[3:2]) 
                            2'b00: s_axi_rdata <= slv_reg0;
                            2'b01: s_axi_rdata <= slv_reg1;
                            2'b10: s_axi_rdata <= slv_reg2;
                            2'b11: s_axi_rdata <= slv_reg3;
                            default: begin
                                s_axi_rdata <= 32'hDEADBEEF;
                                s_axi_rresp <= RESP_SLVERR;
                            end
                        endcase
                    end
                end
            endcase
        end 
    end 
endmodule