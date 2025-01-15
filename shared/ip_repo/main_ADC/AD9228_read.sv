//adc  (diff -> single ended), csb (single ended) needs to be handled here

module AD9228_read #(
    NUM_CHANNELS = 8
) (
    //common inputs
    input logic clk, //65 Mhz
    input logic rstn,

    //AD9228 inputs (indexed by channel)
    input logic [NUM_CHANNELS-1 : 0] din_p,
    input logic [NUM_CHANNELS-1 : 0] din_n,
    input logic [NUM_CHANNELS-1 : 0] fco_p,
    input logic [NUM_CHANNELS-1 : 0] fco_n,
    input logic [NUM_CHANNELS-1 : 0] dco_p,
    input logic [NUM_CHANNELS-1 : 0] dco_n,
);


endmodule