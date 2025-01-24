//datasheet: https://www.analog.com/media/en/technical-documentation/data-sheets/ad9228.pdf

//clk is input clock, sampling clock, always on
//csb is to start a command
//FCO is a ready signal
//DCO is clk * 12 (resolution), data is clocked out ddr on DCO

//differential -> single-ended for DCO, VINA,B,C,D
//ddr shift reg/SERDES clocked on DCO
// - SERDES does deserialization automatically into bytes
// - then use "gearbox" to turn bytes into 12bit words, at relative frequency
//then put into FIFO (with a trigger)

module AD9228_single_ch_read #(
    parameter integer FIFO_DEPTH = 2048,
    parameter DATA_WIDTH = 12

)(
    //common inputs
    input logic clk,
    input logic rstn,

    //AD9228 inputs
    input logic din_p,
    input logic din_n,
    input logic fco_p,
    input logic fco_n,
    input logic dco_p,
    input logic dco_n,

    //FIFO connections
    input logic fifo_rd_en,
    output logic fifo_not_empty,
    output logic fifo_full,
    output logic [7:0] fifo_dout
);

    logic din;
    logic fco;
    logic dco;

    //fifo logic
    logic [DATA_WIDTH-1:0] des_data;
    logic read_complete;

    diff_to_single_ended din_conv (
        .diff_p (din_p),
        .diff_n (din_n),
        .single_out (din)
    );

    diff_to_single_ended fco_conv (
        .diff_p (fco_p),
        .diff_n (fco_n),
        .single_out (fco)
    );

    diff_to_single_ended dco_conv (
        .diff_p (dco_p),
        .diff_n (dco_n),
        .single_out (dco)
    );

    AD9228_core core_inst (
        //inputs
        .rstn (rstn),

        //adc inputs
        .din (din),
        .fco (fco),
        .dco (dco),

        //outputs
        .des_data (des_data),
        .read_complete (read_complete)
    );

endmodule