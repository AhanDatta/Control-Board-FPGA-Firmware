module pll_external #(
    parameter ADC_WIDTH = 16;
    parameter DAC_WIDTH = 16;
) (
    input logic clk, //for both adc and dac drivers
    input logic adc_resetn, //needs to be held
    input logic input_from_adc,
    output logic adc_sck,
    output logic adc_cnv,
    output logic adc_resetn_confirm,
    input logic dac_aresetn, 
    output logic dac_sclk,
    output logic dac_write,
    output logic dac_syncn
);

    logic [ADC_WIDTH-1:0] amplified_data;

    AD4008_read adc_in (
        .clk (clk),
        .aresetn (adc_resetn),
        .data_in (input_from_adc),
        .cnv (adc_cnv),
        .sck (adc_sck),
        .sresetn (adc_resetn_confirm),
        .new_data_flag (),
        .amplified_data (amplified_data)
    );

    DAC8411_write dac_out (
        .clk (clk),
        .aresetn (dac_aresetn),
        .data_in (amplified_data),
        .sclk (dac_sclk),
        .serial_data_out (dac_write),
        .syncn (dac_syncn)
    );

endmodule