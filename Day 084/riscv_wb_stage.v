module riscv_wb_stage (
    input [31:0] mem_wb_wdata,
    input [4:0] mem_wb_rd,
    input [6:0] mem_wb_opcode,
    input mem_wb_reg_write,

    //Outputs to register file write port(To ID stage)
    output [31:0] wb_rf_wdata,
    output [4:0] wb_rf_rd,
    output wb_rf_reg_write,

    //To EX stage forwarding unit
    output [31:0] wb_fwd_data,

    //Verification Signals
    output wb_retired_valid,
    output [4:0] wb_retired_rd,
    output [31:0] wb_retired_data
);
    //Suppress write if destination is to address zero
    wire is_rd_valid = (mem_wb_rd != 5'd0);

    assign wb_rf_wdata = mem_wb_wdata;
    assign wb_rf_rd = mem_wb_rd;
    assign wb_rf_reg_write = mem_wb_reg_write & is_rd_valid;

    //Forwarding bus
    assign wb_fwd_data = mem_wb_wdata;

    //Retire if opcode is valid
    assign wb_retired_valid = (mem_wb_opcode != 7'b0000000);
    assign wb_retired_rd = wb_rf_rd;
    assign wb_retired_data = wb_rf_wdata;

endmodule