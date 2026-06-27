// A 4 bit right shift register with serial input and parallel/serial outputs

module shift_reg(input clk, serial_in, nreset, load, output reg [3:0] data_parallel, output serial_out);    
    assign serial_out = data_parallel[0];
    always@(posedge clk or negedge nreset) begin
        if(!nreset) data_parallel <= 4'd0;
        else begin
            if(load) begin 
                data_parallel <= {serial_in, data_parallel[3:1]};
            end
            else data_parallel <= data_parallel;
        end
    end
endmodule
