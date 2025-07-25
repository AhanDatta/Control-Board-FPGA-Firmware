//3 Wire busy signal mode https://www.analog.com/media/en/technical-documentation/data-sheets/ad4000-4004-4008.pdf
//Put data in FIFO for dbg
//Multiply the signal by some tunable parameter
//Put the signal on an output for the DAC

module AD4008_read #(
    parameter ADC_WIDTH = 16,
    parameter NUM_FRAC_BITS = 8 //8,8 bit fixed point numbers
) (
    input logic clk, //same freq as DAC8411
    input logic aresetn,
    input logic [15:0] GAIN, 
    input logic data_in, //Also acts as the busy signal, detailed in above datasheet
    output logic cnv,
    output logic sck,
    output logic sresetn, //To check if the reset has happened yet
    output logic new_data_flag, //For the dac8411 driver to start writing
    output logic [ADC_WIDTH-1:0] amplified_data
);

    typedef enum logic [1:0] { RESET, INIT_CONVERSION, WAIT_FOR_RESULT, READ_IN } state_t;

    state_t state;
    logic [ADC_WIDTH-1:0] raw_data;
    logic [2*ADC_WIDTH-1:0] temp_amplified_data;
    logic [$clog2(ADC_WIDTH)-1:0] readin_counter; // Use proper width for counter
    logic sck_enable;
    logic read_in_progress;

    // Output the ADC reset - combine primary reset with read protection
    assign sresetn = aresetn && !read_in_progress;

    //in pseudocode: sck=clk if (sck_enable==1) else sck = 0
    ODDRE1 #(
      .IS_C_INVERTED(1'b0),           // Optional inversion for C
      .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality
      .SRVAL(1'b0)                    // Initializes the ODDRE1 Flip-Flops to the specified value
   )
   ODDRE1_inst (
      .Q(sck),   // 1-bit output: Data output to IOB
      .C(clk),   // 1-bit input: High-speed clock input
      .D1(sck_enable), // 1-bit input: Parallel data input 1
      .D2(1'b0), // 1-bit input: Parallel data input 2
      .SR(!aresetn)  // Use primary reset for the primitive
   );

    assign amplified_data = temp_amplified_data[ADC_WIDTH+NUM_FRAC_BITS-1:NUM_FRAC_BITS];

    //Main state machine - USE PRIMARY RESET ONLY
    always_ff @(posedge clk or negedge aresetn) begin
        if (!aresetn) begin
            state <= RESET;
            raw_data <= '0;
            sck_enable <= 1'b0;
            new_data_flag <= 1'b0;
            cnv <= 1'b0;
            temp_amplified_data <= '0;
            readin_counter <= '0;
            read_in_progress <= 1'b0; // Initialize this signal
        end 
        else begin
            case (state)
                RESET: begin
                    read_in_progress <= 1'b0;
                    sck_enable <= 1'b0;
                    cnv <= 1'b0;
                    new_data_flag <= 1'b0;
                    state <= INIT_CONVERSION; //at the end of a reset, start converting again
                end

                INIT_CONVERSION: begin
                    read_in_progress <= 1'b0;
                    cnv <= 1'b1;
                    sck_enable <= 1'b0;
                    state <= WAIT_FOR_RESULT;
                    // Perform multiplication with proper bit handling
                    temp_amplified_data <= raw_data * GAIN;
                    new_data_flag <= 1'b1;
                end

                WAIT_FOR_RESULT: begin
                    cnv <= 1'b0;
                    new_data_flag <= 1'b0;
                    if (data_in == 1'b0) begin //this is the busy signal
                        readin_counter <= ADC_WIDTH-1;
                        sck_enable <= 1'b1;
                        read_in_progress <= 1'b1; // Set before entering read state
                        state <= READ_IN;
                    end
                    // else stay in WAIT_FOR_RESULT
                end

                READ_IN: begin
                    read_in_progress <= 1'b1;
                    raw_data[readin_counter] <= data_in;
                    if(readin_counter == 0) begin
                        sck_enable <= 1'b0;
                        read_in_progress <= 1'b0; // Clear when done reading
                        state <= INIT_CONVERSION;
                    end 
                    else begin
                        readin_counter <= readin_counter - 1;
                        // stay in READ_IN state
                    end
                end

                default: begin
                    state <= RESET;
                end
            endcase
        end
    end

endmodule