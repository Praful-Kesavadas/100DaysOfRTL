module crc32_generator #(
    parameter DATA_WIDTH = 8,
    parameter CRC_WIDTH = 32
)(
    input clk, nreset, init, data_valid,
    input [DATA_WIDTH-1:0] data_in,
    output [CRC_WIDTH-1:0] crc_out, crc_state,
    output crc_valid
);
    localparam [CRC_WIDTH-1:0] POLYNOMIAL = 32'hEDB88320; //Standard IEEE CRC-32 polynomial
    localparam [CRC_WIDTH-1:0] INIT_SEED = 32'hFFFFFFFF; 

    //LFSR state register and valid register
    reg [CRC_WIDTH-1:0] lfsr_reg;
    reg valid_reg;

    //Combinational Function to perform the Shift-and-XOR function per byte
    function [CRC_WIDTH-1:0] calc_next_crc;
        input [CRC_WIDTH-1:0] curr_crc;
        input [DATA_WIDTH-1:0] data_byte;

        reg [CRC_WIDTH-1:0] crc;
        integer i;

        begin
            //XOR incoming byte with the last 8 bits of the current crc
            crc = curr_crc ^ {24'd0, data_byte};

            //Do the 8 shift-and-XOR operations per byte
            for(i = 0; i < 8; i = i + 1) begin
                if(crc[0]) crc = (crc >> 1) ^ POLYNOMIAL;
                else crc = (crc >> 1);
            end

            calc_next_crc = crc;
        end
    endfunction

    //Sequential Logic
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            lfsr_reg <= 0;
            valid_reg <= 0;
        end
        else if(init) begin
            valid_reg <= 0;
            if(data_valid) lfsr_reg <= calc_next_crc(INIT_SEED, data_in);
            else lfsr_reg <= INIT_SEED;
        end
        else if(data_valid) begin
            lfsr_reg <= calc_next_crc(lfsr_reg, data_in);
            valid_reg <= 0;
        end
        else begin
            valid_reg <= 1'b1;
        end
    end

    //Final Output assignments
    assign crc_state = lfsr_reg;
    assign crc_out = lfsr_reg ^ INIT_SEED;
    assign crc_valid = valid_reg;

endmodule
