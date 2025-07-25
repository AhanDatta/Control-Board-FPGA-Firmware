//Must be greater than 1ps/ps
`timescale 1ns/1ps

module pll_external_testbench #(
    parameter DAC_WIDTH = 16
) ();

    logic DBG_READOUT = 1;

    logic aresetn;
    logic clk;

    //wires with DAC
    logic sclk;
    logic data_to_dac;
    logic syncn; 

    //wires with ADC
    logic new_data_flag; //UNUSED: kept for future use?
    logic sresetn;
    logic sdo; //serial data in
    logic cnv; //convert signal
    logic sck; //readout clk
    logic [DAC_WIDTH-1:0] fake_data; //data inside ADC

    //Between ADC and DAC drivers
    logic [DAC_WIDTH-1:0] amplified_adc_counts;

    always #10 clk = ~clk;

    AD4008_read AD4008_read_inst (
        .clk (clk),
        .aresetn(aresetn),
        .data_in (sdo),
        .cnv (cnv),
        .sck (sck),
        .sresetn (sresetn),
        .new_data_flag (new_data_flag),
        .amplified_data (amplified_adc_counts)
    );

    AD4008_emulator AD4008_emulator_inst (
        .fake_data (fake_data),
        .cnv (cnv),
        .sck (sck),
        .sdo (sdo)
    );

    DAC8411_write DAC8411_write_inst (
        .data_in (amplified_adc_counts),
        .aresetn (aresetn),
        .clk (clk),
        .sclk (sclk),
        .serial_data_out (data_to_dac),
        .syncn (syncn)
    );

    //external reseting both drivers
    task ext_reset ();
        aresetn = 0;
        wait (sresetn == 1'b0);
        @(negedge clk);
        aresetn = 1;

        $display("External Reset -------------------------------------------------------------------------------------------------------------------------");
    endtask

    initial begin
        //resetting and initial values
        fake_data = 'b10101010_10101010;
        clk = 1;
        aresetn = 1;
        #50;
        ext_reset();

        #650;
      	fake_data = 'b00000000_11110000;
      	#650;
    end

endmodule