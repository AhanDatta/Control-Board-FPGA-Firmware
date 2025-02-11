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

    //FIFO connections (indexed by channel)
    input logic [NUM_CHANNELS-1 : 0] fifo_rd_en,
    input logic [NUM_CHANNELS-1 : 0] fifo_rd_clk,
    output logic [NUM_CHANNELS-1 : 0] fifo_not_empty,
    output logic [NUM_CHANNELS-1 : 0] fifo_full,
    output logic [NUM_CHANNELS-1 : 0][DATA_WIDTH-1:0] fifo_dout
);

    genvar i;
    generate
        for (i=0; i < NUM_CHANNELS; i = i+1) begin : channel_instantiations
            AD9228_single_ch_read  AD9228_single_ch_read_inst (
                .clk (clk),
                .rstn (rstn),

                .din_p (din_p[i]),
                .din_n (din_n[i]),
                .fco_p (fco_p[i]),
                .fco_n (fco_n[i]),
                .dco_p (dco_p[i]),
                .dco_n (dco_n[i]),

                .fifo_rd_en (fifo_rd_en[i]),
                .fifo_rd_clk (fifo_rd_clk[i]),
                .fifo_not_empty (fifo_not_empty[i]),
                .fifo_full (fifo_full[i]),
                .fifo_dout (fifo_dout[i])
            );
        end
    endgenerate

endmodule