module pic_core #(
    parameter NUM_IRQS = 8,             //Total interrupt lines(0 = Highest priority)
    parameter ADDR_WIDTH = 16,          // Vector Address bit width
    parameter BASE_VECTOR = 16'h1000    // Base address for vector 0
)(
    input clk, nreset,
    input [NUM_IRQS-1:0] irq_req,       // Hardware request inputs
    input imr_write,                    // Write to update the mask register
    input [NUM_IRQS-1:0] imr_in,        // Mask/unmask specific requests (1 to disable)
    input irq_ack,                      // Software accepts the current irq
    input eoi,                          // End of Interrupt

    output reg irq_out,                     // Request line to the CPU core's IRQ pin
    output reg [ADDR_WIDTH-1:0] irq_vector  // Target ISR vector memory address to the CPU
);

    reg [NUM_IRQS-1:0] irr; // Interrupt request register
    reg [NUM_IRQS-1:0] imr; // Interrupt mask register
    reg [NUM_IRQS-1:0] isr; // In-Service register

    //Intermeditate Signals
    wire [NUM_IRQS-1:0] active_reqs;
    reg [NUM_IRQS-1:0] highest_priority_irq;
    integer i;

    //Bit masking
    assign active_reqs = irr & ~(imr);

    //Interrupt Mask Register Updates
    always@(posedge clk or negedge nreset) begin
        if(!nreset) imr <= {NUM_IRQS{1'b0}};
        else if(imr_write) imr <= imr_in;
    end

    //Select the most priority interrupt request and the index
    reg [$clog2(NUM_IRQS)-1:0] winning_index;
    always @(*) begin
        highest_priority_irq = {NUM_IRQS{1'b0}};
        winning_index   = 0;
        for (i = NUM_IRQS - 1; i >= 0; i = i - 1) begin
            if (active_reqs[i]) begin
                highest_priority_irq = (1'b1 << i);
                winning_index   = i[$clog2(NUM_IRQS)-1:0];
            end
        end
    end

    // Interrupt Request Register Tracking
    always@(posedge clk or negedge nreset) begin
        if(!nreset) irr <= 0;
        else begin
            if(irq_ack) irr <= (irr | irq_req) & ~highest_priority_irq;     // Clear the already acknowledged req
            else irr <= irr | irq_req;
        end
    end

    // In Service Register Tracking
    always@(posedge clk or negedge nreset) begin
        if(!nreset) isr <= 0;
        else begin
            if(irq_ack) begin
                isr <= isr | highest_priority_irq;
            end
            else if(eoi) begin
                isr <= isr & (isr - 1'b1);    // Clear the lowest active bit
            end
        end
    end

    // Pre-emption Logic so that the PIC will assert irq_out only if a higher priority req than the currently being processed request comes
    wire [NUM_IRQS-1:0] lowest_isr_bit = isr & (~isr + 1'b1);
    wire can_preempt = (isr == 0 || (highest_priority_irq < lowest_isr_bit));
    // Output generation
    always@(posedge clk or negedge nreset) begin
        if(!nreset) begin
            irq_out <= 0;
            irq_vector <= 0;
        end
        else begin
            if((active_reqs != {NUM_IRQS{1'b0}}) && can_preempt) begin
                irq_out <=  1'b1;
                irq_vector <= BASE_VECTOR + (winning_index << 2); //4 bytes offset per vector
            end
            else begin
                irq_out <= 0;
                irq_vector <= {ADDR_WIDTH{1'b0}};
            end
        end
    end
endmodule