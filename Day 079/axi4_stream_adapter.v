module axis_protocol_adapter (
    input aclk, aresetn,

    //Upstream AXI4-Stream Slave Interface(32 bit input) -> Collects data from MASTER
    input [31:0] s_axis_tdata,
    input [3:0] s_axis_tkeep,
    input s_axis_tlast,
    input s_axis_tvalid,
    output s_axis_tready,

    //Downstream Master Interface(8 bit input) -> Drives data to the SLAVE
    output reg [7:0] m_axis_tdata,
    output reg m_axis_tkeep,
    output reg m_axis_tlast,
    output reg m_axis_tvalid,
    input m_axis_tready
);
    //Latching registers
    reg [31:0] latched_data;
    reg [3:0] latched_keep;
    reg latched_last;

    //FSM States
    localparam S_IDLE = 3'd0;
    localparam S_BYTE0 = 3'd1;
    localparam S_BYTE1 = 3'd2;
    localparam S_BYTE2 = 3'd3;
    localparam S_BYTE3 = 3'd4;

    reg [2:0] state, next_state;

    //Check if the current byte is the final valid byte of the latched word
    wire is_last_byte = (state == S_BYTE3) ||
                        (state == S_BYTE2 && !latched_keep[3]) ||
                        (state == S_BYTE1 && !latched_keep[2]) ||
                        (state == S_BYTE0 && !latched_keep[1]);
    
    //Upstream ready when state is IDLE or on the final byte transfer and downstream asserts ready
    assign s_axis_tready = (state == S_IDLE) || (is_last_byte && m_axis_tready);

    //Next State Logic
    always@(*) begin
        next_state = state;

        case(state)
            S_IDLE: begin
                if(s_axis_tvalid && s_axis_tready) next_state = S_BYTE0;
            end
            S_BYTE0: begin
                if(m_axis_tready) begin
                    if(!latched_keep[1]) begin
                        //Word ends at byte 0, hence accept another word into the same position or move to IDLE
                        if(s_axis_tready && s_axis_tvalid) next_state = S_BYTE0;
                        else next_state = S_IDLE;
                    end
                    else next_state = S_BYTE1;
                end
            end

            S_BYTE1: begin
                if(m_axis_tready) begin
                    if(!latched_keep[2]) begin
                        //Word ends at byte 1, hence start accepting a new word
                        if(s_axis_tready && s_axis_tvalid) next_state = S_BYTE0;
                        else next_state = S_IDLE;
                    end
                    else next_state = S_BYTE2;
                end
            end

            S_BYTE2: begin
                if(m_axis_tready) begin
                    if(!latched_keep[2]) begin
                        //Word ends at byte 2
                        if(s_axis_tready && s_axis_tvalid) next_state = S_BYTE0;
                        else next_state = S_IDLE;
                    end
                    else next_state = S_BYTE3;
                end
            end

            S_BYTE3: begin
                if(m_axis_tready) begin
                    if(s_axis_tready && s_axis_tvalid) next_state = S_BYTE0;
                    else next_state = S_IDLE;
                end
            end

            default: next_state = S_IDLE;
        endcase
    end

    //State Transition
    always@(posedge aclk or negedge aresetn) begin
        if(!aresetn) state <= S_IDLE;
        else state <= next_state;
    end

    //Register Updates
    always@(posedge aclk or negedge aresetn) begin
        if(!aresetn) begin
            latched_data <= 32'd0;
            latched_keep <= 4'd0;
            latched_last <= 1'b0;
            m_axis_tdata <= 8'h00;
            m_axis_tkeep <= 1'b0;
            m_axis_tlast <= 1'b0;
            m_axis_tvalid <= 1'b0;
        end
        else begin
            case(next_state)
                S_IDLE: begin
                    m_axis_tvalid <= 1'b0;
                    m_axis_tkeep <= 1'b0;
                    m_axis_tlast <= 1'b0;
                end
                S_BYTE0: begin
                    if(s_axis_tvalid && s_axis_tready) begin
                        latched_data <= s_axis_tdata;
                        latched_keep <= s_axis_tkeep;
                        latched_last <= s_axis_tlast;
                        m_axis_tdata <= s_axis_tdata[7:0];
                        m_axis_tkeep <= s_axis_tkeep[0];
                        m_axis_tlast <= (s_axis_tlast && !s_axis_tkeep[1]);
                        m_axis_tvalid <= s_axis_tkeep[0];
                    end
                end
                S_BYTE1: begin
                    m_axis_tdata <= latched_data[15:8];
                    m_axis_tkeep <= latched_keep[1];
                    m_axis_tlast <= (latched_last && !latched_keep[2]);
                    m_axis_tvalid <= 1'b1;
                end
                S_BYTE2: begin
                    m_axis_tdata <= latched_data[23:16];
                    m_axis_tkeep <= latched_keep[2];
                    m_axis_tlast <= (latched_last && !latched_keep[3]);
                    m_axis_tvalid <= 1'b1;
                end
                S_BYTE3: begin
                    m_axis_tdata <= latched_data[31:24];
                    m_axis_tkeep <= latched_keep[3];
                    m_axis_tlast <= latched_last;
                    m_axis_tvalid <= 1'b1;
                end
                default: begin
                    m_axis_tvalid <= 1'b0;
                end
            endcase
        end
    end
endmodule