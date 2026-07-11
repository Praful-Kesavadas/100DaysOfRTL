module vending_machine_controller#(parameter PRICE1 = 10, PRICE2 = 15, PRICE3 = 20, WIDTH = 8)(input clk, nreset, cancel_transaction, done_in, input [2:0] item_select, input [1:0] coin_trigger, input [1:0] quantity, output reg condition_met, output reg [WIDTH-1:0] change_out);

    //States
    localparam IDLE = 3'd0;
    localparam ITEM_SEL = 3'd1;
    localparam MONEY_IN = 3'd2;
    localparam TRANS_CANCEL = 3'd3;
    localparam INSUFFICIENT_AMOUNT = 3'd4;
    localparam ITEM_DISPOSE = 3'd5;
    localparam BALANCE_ISSUE = 3'd6;

    //Coin types
    localparam [WIDTH-1:0] VAL_NICKEL  = 5;
    localparam [WIDTH-1:0] VAL_DIME    = 10;
    localparam [WIDTH-1:0] VAL_QUARTER = 25;
    localparam [WIDTH-1:0] VAL_ZERO    = 0;

    reg [WIDTH-1:0] credit_accum, target_cost, base_price;
    reg [2:0] state, next_state;
    reg credit_ok;
    
    wire [WIDTH-1:0] coin_value, next_credit_pred;
    assign coin_value = (coin_trigger == 2'b01) ? VAL_NICKEL :
                        (coin_trigger == 2'b10) ? VAL_DIME   :
                        (coin_trigger == 2'b11) ? VAL_QUARTER: VAL_ZERO;

    // Lookahead Credit Tracking Net to Eliminate 1-Cycle Latency Lag
    assign next_credit_pred = (state == MONEY_IN && |coin_trigger && !cancel_transaction) ? credit_accum + coin_value :
                              credit_accum;


    // Base price select
    always@(*) begin
        case(item_select)
            3'b001: base_price = PRICE1;
            3'b010: base_price = PRICE2;
            3'b100: base_price = PRICE3;
            default: base_price = {WIDTH{1'b1}};
        endcase
    end
    // Credit met check
    always@(posedge clk or negedge nreset) begin
        if(!nreset) credit_ok <= 1'b0;
        else credit_ok <= (next_credit_pred >= target_cost);
    end

    // Next state logic
    always@(*) begin
        next_state = state;
        case(state) 
            IDLE:   begin
                        if(|(item_select) && (quantity > 0)) next_state = ITEM_SEL;
                    end 
            ITEM_SEL: begin 
                        if(cancel_transaction) next_state = TRANS_CANCEL;
                        else next_state = MONEY_IN;
                      end
            MONEY_IN: begin
                        if(cancel_transaction) next_state = TRANS_CANCEL;
                        else if(done_in) next_state = credit_ok ? ITEM_DISPOSE : INSUFFICIENT_AMOUNT;
                        else next_state = MONEY_IN;
                      end
            TRANS_CANCEL: next_state = (credit_accum > {WIDTH{1'b0}}) ? BALANCE_ISSUE : IDLE;
            INSUFFICIENT_AMOUNT: next_state = BALANCE_ISSUE;
            ITEM_DISPOSE: next_state = BALANCE_ISSUE;
            BALANCE_ISSUE: next_state = IDLE;
            default: next_state = IDLE;
        endcase    
    end

    // State Change
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            state <= IDLE;
        end
        else state <= next_state;
    end

    // Register Updates
    always @(posedge clk or negedge nreset) begin
        if(!nreset) begin
            credit_accum <= {WIDTH{1'b0}};
            change_out <= {WIDTH{1'b0}};
            target_cost <= {WIDTH{1'b0}};
            condition_met <= 1'b0;
        end
        else begin
            condition_met <= 1'b0;
            case(state)
                IDLE: begin
                    credit_accum <= {WIDTH{1'b0}};
                    change_out <= {WIDTH{1'b0}};
                end
                ITEM_SEL: begin
                    target_cost <= base_price * quantity;
                end
                MONEY_IN: begin
                    if(|coin_trigger && (!cancel_transaction)) credit_accum <= credit_accum + coin_value;
                end
                TRANS_CANCEL: begin
                    change_out <= credit_accum;
                end
                ITEM_DISPOSE: begin
                    condition_met <= 1'b1;
                    change_out <= credit_accum - target_cost;
                end
                INSUFFICIENT_AMOUNT: begin
                    change_out <= credit_accum;
                end
                BALANCE_ISSUE: begin
                    change_out <= {WIDTH{1'b0}};
                    credit_accum <= {WIDTH{1'b0}};
                end
            endcase
        end 
    end 
endmodule