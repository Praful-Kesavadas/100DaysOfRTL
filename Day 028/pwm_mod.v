// To assert the output pwm_out pin high for a time corresponding to the duty cycle input

module pwm_modulator #(parameter WIDTH = 8)(input clk, nreset, start, input [WIDTH-1:0] duty_cycle, output reg pwm_out);
    reg [WIDTH-1:0] counter;
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            counter <= {WIDTH{1'b0}};
            pwm_out <= 0;
        end
        else if(start) begin
            counter <= counter + 1;
            if(duty_cycle == {WIDTH{1'b0}}) pwm_out <= 1'b0;
            else if(duty_cycle == {WIDTH{1'b1}}) pwm_out <= 1'b1;
            else pwm_out <= (counter < duty_cycle);
        end
        else begin 
            pwm_out <= 1'b0;
            counter <= {WIDTH{1'b0}};
        end
    end
endmodule
