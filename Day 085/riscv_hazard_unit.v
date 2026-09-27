module riscv_hazard_unit (
    //Use detection Inputs
    input id_ex_mem_read,
    input [4:0] id_ex_rd,
    input [4:0] if_id_rs1, if_id_rs2,
    input if_id_rs1_used, if_id_rs2_used,

    //Control Hazard detection input
    input ex_branch_taken,

    //Output 
    output reg stall_if, stall_id,
    output reg flush_id, flush_ex
);
    wire load_use_hazard;

    assign load_use_hazard = id_ex_mem_read && (id_ex_rd != 5'd0) &&
                             ((if_id_rs1_used && (id_ex_rd == if_id_rs1)) ||
                              (if_id_rs2_used && (id_ex_rd == if_id_rs2)));

    always@(*) begin
        stall_if = 1'b0;
        stall_id = 1'b0;
        flush_id = 1'b0;
        flush_ex = 1'b0;

        //Control Hazard(priority)
        if(ex_branch_taken) begin
            flush_id = 1'b1; //Flush the instruction fetched after branch
            flush_ex = 1'b1; //Flush the instruction currently in decode
        end
        //Data hazard(Load use interlock)
        else if(load_use_hazard) begin
            stall_if = 1'b1; // Freeze the program counter
            stall_id = 1'b1; // Freeze IF/ID register
            flush_ex = 1'b1; // Inject NOP into ID/EX register
        end
    end

endmodule