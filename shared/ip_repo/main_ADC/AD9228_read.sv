//adc clk (diff -> single ended), csb (single ended) needs to be handled here

module AD9228_read #(
    parameter integer NUM_CHANNELS = 4,
    parameter integer DATA_WIDTH = 12
) (
    //common inputs
    input logic clk, // <65 Mhz, ~40 Mhz
    input logic rstn,
    input logic read_en,

    //AD9228 inputs (indexed by channel)
    input logic [NUM_CHANNELS-1 : 0] din_p,
    input logic [NUM_CHANNELS-1 : 0] din_n,
    input logic fco_p,
    input logic fco_n,
    input logic dco_p,
    input logic dco_n,

    //Common/SPI adc connections
    output logic clk_p,
    output logic clk_n,

    //FIFO connections (indexed by channel)
    input logic [$clog2(NUM_CHANNELS)-1:0] fifo_addr,
    input logic [NUM_CHANNELS-1:0] fifo_rd_en,
    input logic fifo_rd_clk,
    output logic fifo_not_empty,
    output logic fifo_full,
    output logic fifo_dout
);

    logic fco;
    logic dco;

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

    logic sample_clk;
    logic [NUM_CHANNELS-1:0][DATA_WIDTH-1:0] premux_fifo_dout;
    logic [NUM_CHANNELS-1:0] premux_fifo_not_empty;
    logic [NUM_CHANNELS-1:0] premux_fifo_full;

    //generating each of the channels
    genvar i;
    generate
        for (i=0; i < NUM_CHANNELS; i = i+1) begin : channel_instantiations
            AD9228_single_ch_read  AD9228_single_ch_read_inst (
                .clk (clk),
                .rstn (rstn),
                .read_en (read_en),

                .din_p (din_p[i]),
                .din_n (din_n[i]),
                .fco (fco),
                .dco (dco),

                .fifo_rd_en (fifo_rd_en[i]),
                .fifo_rd_clk (fifo_rd_clk),
                .fifo_not_empty (premux_fifo_not_empty[i]),
                .fifo_full (premux_fifo_full[i]),
                .fifo_dout (premux_fifo_dout[i])
            );
        end
    endgenerate

    //Muxing the fifo dout
    always_comb begin
        if (!rstn) begin
            fifo_dout = '0;
            fifo_not_empty = 0;
            fifo_full = 0;
        end
        else begin
            fifo_dout = premux_fifo_dout[fifo_addr];
            fifo_not_empty = premux_fifo_not_empty[fifo_addr];
            fifo_full = premux_fifo_full[fifo_addr];
        end
    end

    //Should always be sampling
    assign sample_clk = clk;

    single_ended_to_diff adc_clk_conv (
        .single_in (sample_clk),
        .diff_p (clk_p),
        .diff_n (clk_n)
    );
endmodule