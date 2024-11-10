module AD4008_testbench #(
    parameter ADC_WIDTH = 16
)(
    input logic clk,
    input logic aresetn,
    output logic new_data_flag,
    output logic [ADC_WIDTH-1:0] amplified_data
);

    logic sdo;
    logic cnv;
    logic sck;

    AD4008_read AD4008_read_inst (
        .clk (clk),
        .aresetn(aresetn),
        .data_in (sdo),
        .cnv (cnv),
        .sck (sck),
        .new_data_flag (new_data_flag),
        .amplified_data (amplified_data)
    );

    AD4008_emulator AD4008_emulator_inst (
        .cnv (cnv),
        .sck (sck),
        .sdo (sdo)
    );

endmodule