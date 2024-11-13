//3 Wire busy signal mode https://www.analog.com/media/en/technical-documentation/data-sheets/ad4000-4004-4008.pdf
//Put data in FIFO for dbg
//Multply the signal by some tunable parameter
//Put the signal on an output for the DAC

module AD4008_read #(
    parameter GAIN = 2,
    parameter ADC_WIDTH = 16
) (
    input logic clk, //same freq as DAC8411
    input logic aresetn,
    input logic data_in, //Also acts as the busy signal, detailed in above datasheet
    output logic cnv,
    output logic sck,
    output logic sresetn, //To check if the reset has happened yet
    output logic new_data_flag, //For the dac8411 driver to start writing
    output logic [ADC_WIDTH-1:0] amplified_data
);

    typedef enum { RESET, INIT_CONVERSION, WAIT_FOR_RESULT, READ_IN } state_t;

    state_t state;
    logic [ADC_WIDTH-1:0] raw_data;
    integer readin_counter;
    logic sck_enable;
    logic read_in_progress;

    assign sresetn = aresetn || read_in_progress; //ensures ADC always gets read out properly

    //in psuedocode: sck=clk if (sck_enable==1) else sck = 0
    ODDRE1 #(
      .IS_C_INVERTED(1'b0),           // Optional inversion for C
      .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE,
                                      // ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
      .SRVAL(1'b0)                    // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
   )
   ODDRE1_inst (
      .Q(sck),   // 1-bit output: Data output to IOB
      .C(clk),   // 1-bit input: High-speed clock input
      .D1(sck_enable), // 1-bit input: Parallel data input 1
      .D2(1'b0), // 1-bit input: Parallel data input 2
      .SR(1'b0)  // 1-bit input: Active-High Async Reset
   );

    //Main state machine
    always_ff @(posedge clk or negedge sresetn) begin
        if (!sresetn) begin
            state <= RESET;
            raw_data <= '0;
            sck_enable <= '0;
            new_data_flag <= 0;
            cnv <= 0;
            amplified_data <= '0;
        end 
        else begin
            case (state)
                RESET:
                begin
                    state <= INIT_CONVERSION; //at the end of a reset, start converting again
                end

                INIT_CONVERSION:
                begin
                    read_in_progress <= 0;
                    cnv <= 1;
                    state <= WAIT_FOR_RESULT;
                    amplified_data <= raw_data * GAIN;
                    new_data_flag <= 1;
                end

                WAIT_FOR_RESULT:
                begin
                    if (data_in == 0) begin //this is the busy signal
                        readin_counter <= ADC_WIDTH-1;
                        sck_enable <= 1;
                        state <= READ_IN;
                    end
                    else begin
                        state <= WAIT_FOR_RESULT;
                    end
                    cnv <= 0;
                    new_data_flag <= 0;
                end

                READ_IN:
                begin
                    read_in_progress <= 1;
                    raw_data[readin_counter] <= data_in;
                    if(readin_counter == 0) begin
                        sck_enable <= 0;
                        state <= INIT_CONVERSION;
                    end 
                    else begin
                        readin_counter <= readin_counter - 1;
                        state <= READ_IN;
                    end
                end
            endcase
        end
    end

endmodule