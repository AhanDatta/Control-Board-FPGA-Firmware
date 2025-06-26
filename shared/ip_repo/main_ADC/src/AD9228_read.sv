//adc clk (diff -> single ended), csb (single ended) needs to be handled here

module AD9228_read #(
    parameter logic DIN_INVERTED = 0,
    parameter logic DCO_INVERTED = 0,
    parameter logic FCO_INVERTED = 0,
    parameter logic SAMPLING_CLK_INVERTED = 0,
    parameter integer NUM_CHANNELS = 4,
    parameter integer DATA_WIDTH = 12
) (
    //common inputs
    input logic clk, // <65 Mhz, ~40 Mhz
    input logic inverted_clk,
    input logic refclk_200M,
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
    input logic fifo_rstn,
    output logic fifo_not_empty,
    output logic fifo_full,
    output logic [DATA_WIDTH-1 : 0] fifo_dout
);

    //processing fco to be usable after inversion
    logic fco;
    logic fco_inv;

    //processing dco for use in SERDES and gearbox
    logic dco;
    logic dco_div4;
    logic dco_inv;

    //sampling clock is gated to clk or clk_inverted
    logic sampling_clk;

    //fifo readout logic and reset
    logic fifo_rstn_sync;
    logic [NUM_CHANNELS-1:0][DATA_WIDTH-1:0] premux_fifo_dout;
    logic [NUM_CHANNELS-1:0] premux_fifo_not_empty;
    logic [NUM_CHANNELS-1:0] premux_fifo_full;

    xpm_cdc_sync_rst #(
      .DEST_SYNC_FF(4),   // DECIMAL; range: 2-10
      .INIT(1),           // DECIMAL; 0=initialize synchronization registers to 0, 1=initialize synchronization
                          // registers to 1
      .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      .SIM_ASSERT_CHK(0)  // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
   )
   ad9228_fifo_rstn_sync_inst (
      .dest_rst(fifo_rstn_sync), // 1-bit output: src_rst synchronized to the destination clock domain. This output
                           // is registered.

      .dest_clk(dco_div4), // 1-bit input: Destination clock.
      .src_rst(fifo_rstn)    // 1-bit input: Source reset signal.
   );

    IBUFDS #(
        .DIFF_TERM("TRUE"),     // Enable internal differential termination
        .IOSTANDARD("LVDS")     // Specify the I/O standard as LVDS
    ) fco_conv (
        .I(fco_p),             // Positive input
        .IB(fco_n),            // Negative input
        .O(fco)          // Single-ended output
    );

    generate
        if (FCO_INVERTED) begin
            assign fco_inv = ~fco;
        end
        else begin
            assign fco_inv = fco;
        end
    endgenerate

    //dco processing
    IBUFDS #(
        .DIFF_TERM("TRUE"),     // Enable internal differential termination
        .IOSTANDARD("LVDS")     // Specify the I/O standard as LVDS
    ) dco_conv (
        .I(dco_p),             // Positive input
        .IB(dco_n),            // Negative input
        .O(dco)          // Single-ended output
    );

    //create divided dco at top level for SERDES at channel level
    generate 
        if (DCO_INVERTED) begin
            BUFGCE_DIV #(
                .BUFGCE_DIVIDE(4),      //divide by 4 for SERDES running in 8bit ddr config
                .IS_CE_INVERTED(1'b0),
                .IS_CLR_INVERTED(1'b1),
                .IS_I_INVERTED(1'b1)
            ) dco_div4_bufgce_inst (
                .O(dco_div4),           //divided clock out
                .CE(1'b1),              //always running clock
                .CLR(),            
                .I(dco)                 //data clock
            );

            BUFGCE #(
                .CE_TYPE("SYNC"),               // ASYNC, HARDSYNC, SYNC
                .IS_CE_INVERTED(1'b0),          // Programmable inversion on CE
                .IS_I_INVERTED(1'b1),           // Programmable inversion on I
                .SIM_DEVICE("ULTRASCALE_PLUS")  // ULTRASCALE, ULTRASCALE_PLUS
            )
            dco_bufgce_inst (
                .O(dco_inv),   // 1-bit output: Buffer
                .CE(1'b1), // 1-bit input: Buffer enable
                .I(dco)    // 1-bit input: Buffer
            );
        end
        else begin
            BUFGCE_DIV #(
                .BUFGCE_DIVIDE(4),      //divide by 4 for SERDES running in 8bit ddr config
                .IS_CE_INVERTED(1'b0),
                .IS_CLR_INVERTED(1'b1),
                .IS_I_INVERTED(1'b0)
            ) dco_div4_inst (
                .O(dco_div4),           //divided clock out
                .CE(1'b1),              //always running clock
                .CLR(),            
                .I(dco)                 //data clock
            );

            BUFGCE #(
                .CE_TYPE("SYNC"),               // ASYNC, HARDSYNC, SYNC
                .IS_CE_INVERTED(1'b0),          // Programmable inversion on CE
                .IS_I_INVERTED(1'b0),           // Programmable inversion on I
                .SIM_DEVICE("ULTRASCALE_PLUS")  // ULTRASCALE, ULTRASCALE_PLUS
            )
            dco_bufgce_inst (
                .O(dco_inv),   // 1-bit output: Buffer
                .CE(1'b1), // 1-bit input: Buffer enable
                .I(dco)    // 1-bit input: Buffer
            );
        end
    endgenerate

    //sampling clock processing
    OBUFDS #(
        .IOSTANDARD("LVDS"), // Specify the I/O standard
        .SLEW("FAST")           // Specify the output slew rate
    ) sampling_clk_inst (
        .I(sampling_clk),          // Single-ended input
        .O(clk_p),             // Positive output
        .OB(clk_n)            // Negative output
    );

    generate 
        if (SAMPLING_CLK_INVERTED) begin
            assign sampling_clk = inverted_clk;
        end
        else begin
            assign sampling_clk = clk;
        end
    endgenerate

    //generating each of the channels
    genvar i;
    generate
        for (i=0; i < NUM_CHANNELS; i = i+1) begin : channel_instantiations
            AD9228_single_ch_read #(
                .DIN_INVERTED(DIN_INVERTED)
            ) AD9228_single_ch_read_inst (
                .clk (clk),
                .refclk_200M (refclk_200M),
                .rstn (rstn),
                .read_en (read_en),

                .din_p (din_p[i]),
                .din_n (din_n[i]),
                .fco (fco_inv),
                .dco (dco_inv),
                .dco_div4 (dco_div4),

                .fifo_rd_en (fifo_rd_en[i]),
                .fifo_rd_clk (fifo_rd_clk),
                .fifo_rstn(fifo_rstn_sync),
                .fifo_not_empty (premux_fifo_not_empty[i]),
                .fifo_full (premux_fifo_full[i]),
                .fifo_dout (premux_fifo_dout[i])
            );
        end
    endgenerate

    //Muxing the fifo dout
    always_comb begin
        if (!fifo_rstn) begin
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
    
endmodule