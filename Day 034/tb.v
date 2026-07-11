`timescale 1ns/1ps

module tb_vending_machine_controller();

    parameter WIDTH = 8;
    
    // Mirror FSM states inside the testbench scope for compilation visibility
    localparam [2:0] IDLE                 = 3'd0;
    localparam [2:0] ITEM_SEL             = 3'd1;
    localparam [2:0] MONEY_IN             = 3'd2;
    localparam [2:0] TRANS_CANCEL         = 3'd3;
    localparam [2:0] INSUFFICIENT_AMOUNT  = 3'd4;
    localparam [2:0] ITEM_DISPOSE         = 3'd5;
    localparam [2:0] BALANCE_ISSUE        = 3'd6;

    reg               clk;
    reg               nreset;
    reg               cancel_transaction;
    reg               done_in;
    reg  [2:0]        item_select;
    reg  [1:0]        coin_trigger;
    reg  [1:0]        quantity;
    wire              condition_met;
    wire [WIDTH-1:0]  change_out;

    // Instantiate UUT Core
    vending_machine_controller #(
        .PRICE1(10),
        .PRICE2(15),
        .PRICE3(20),
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .nreset(nreset),
        .cancel_transaction(cancel_transaction),
        .done_in(done_in),
        .item_select(item_select),
        .coin_trigger(coin_trigger),
        .quantity(quantity),
        .condition_met(condition_met),
        .change_out(change_out)
    );

    // Clock Strobe Engine (100 MHz)
    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);
        clk = 0;
        nreset = 0;
        cancel_transaction = 0;
        done_in = 0;
        item_select = 3'b000;
        coin_trigger = 2'b00;
        quantity = 2'b00;

        // Reset Sequence
        #25;
        nreset = 1;
        #20;

        // --- TEST CASE 1: Overpayment & Change Distribution (Item 1, Qty 1 = Cost 10) ---
        $display("[TB STATE] Initiating Transaction Frame 1 (Overpayment)...");
        item_select = 3'b001;
        quantity = 2'b01;
        #20;
        item_select = 3'b000;

        // Insert 2 Quarters (25 x 2 = 50 total credit)
        coin_trigger = 2'b11; #20; 
        coin_trigger = 2'b00; #20;
        coin_trigger = 2'b11; #20;
        coin_trigger = 2'b00; #20;

        // Confirm insertion done
        done_in = 1; #20;
        done_in = 0;

        wait(uut.state == IDLE);
        #40;

        // --- TEST CASE 2: Cancel/Refund Request Frame ---
        $display("[TB STATE] Initiating Transaction Frame 2 (Cancellation)...");
        item_select = 3'b010; // Item 2
        quantity = 2'b01;
        #20;
        item_select = 3'b000;

        // Insert 1 Dime (10)
        coin_trigger = 2'b10; #20;
        coin_trigger = 2'b00; #20;

        // Hit Cancel Button mid-transaction
        cancel_transaction = 1; #20;
        cancel_transaction = 0;

        wait(uut.state == IDLE);
        #40;

        $display("[TB STATE] All verification sweeps complete.");
        $finish;
    end

endmodule