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
    logic [7:0] fco_byte; 
    logic [7:0] fco_byte_inv; //used down in gearbox

    //processing dco for use in SERDES and gearbox
    logic dco;
    logic dco_bufg; //buffered dco input to MMCM
    logic dco_div4;
    logic dco_for_serdes;
    logic dco_div4_bufg;
    logic dco_for_serdes_bufg;
    logic mmcm_feedback;

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
            assign fco_byte_inv = ~fco_byte;
        end
        else begin
            assign fco_byte_inv = fco_byte;
        end
    endgenerate

    ISERDESE3 #(
        .DATA_WIDTH(8),          //8-bit deserializer
        .FIFO_ENABLE("FALSE"),
        .FIFO_SYNC_MODE("FALSE"),
        .IS_CLK_B_INVERTED(1'b1), 
        .IS_CLK_INVERTED(1'b0),    
        .IS_RST_INVERTED(1'b1),
        .SIM_DEVICE("ULTRASCALE_PLUS")
    ) fco_serdes (
        .FIFO_EMPTY(),
        .INTERNAL_DIVCLK(),
        .Q(fco_byte),        //deserialized output data
        .CLK(dco_for_serdes),           //high-speed DDR clock
        .CLKDIV(dco_div4),        //divided clock
        .CLK_B(dco_for_serdes),
        .D(fco),
        .FIFO_RD_CLK(1'b0),
        .FIFO_RD_EN(1'b0),
        .RST(rstn)
    );

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
    BUFG dco_bufg_inst (
        .I(dco),
        .O(dco_bufg)
    );

    generate 
        if (DCO_INVERTED) begin
            MMCME4_BASE #(
                .BANDWIDTH("OPTIMIZED"),     // Jitter programming (OPTIMIZED, HIGH, LOW)
                .CLKFBOUT_MULT_F(4.0),      // Multiply value for all CLKOUT (2.000-64.000)
                .CLKFBOUT_PHASE(0.0),       // Phase offset in degrees of CLKFB
                .CLKIN1_PERIOD(4.17),       // Input clock period in ns 
                
                // CLKOUT0 configuration - Inverted version of dco
                .CLKOUT0_DIVIDE_F(4.0),     // Divide amount for CLKOUT0 (1.000-128.000)
                .CLKOUT0_DUTY_CYCLE(0.5),   // Duty cycle for CLKOUT0 (0.01-0.99)
                .CLKOUT0_PHASE(0.0),      // Phase offset for CLKOUT0 (-360.000-360.000) - 180° for inversion
                
                // CLKOUT1 configuration - Divided by 4 version of dco
                .CLKOUT1_DIVIDE(16),        // Divide amount for CLKOUT1 (1-128)
                .CLKOUT1_DUTY_CYCLE(0.5),   // Duty cycle for CLKOUT1 (0.01-0.99)
                .CLKOUT1_PHASE(0.0),        // Phase offset for CLKOUT1 (-360.000-360.000)
                
                // Unused outputs
                .CLKOUT2_DIVIDE(1),
                .CLKOUT2_DUTY_CYCLE(0.5),
                .CLKOUT2_PHASE(0.0),
                .CLKOUT3_DIVIDE(1),
                .CLKOUT3_DUTY_CYCLE(0.5),
                .CLKOUT3_PHASE(0.0),
                .CLKOUT4_DIVIDE(1),
                .CLKOUT4_DUTY_CYCLE(0.5),
                .CLKOUT4_PHASE(0.0),
                .CLKOUT5_DIVIDE(1),
                .CLKOUT5_DUTY_CYCLE(0.5),
                .CLKOUT5_PHASE(0.0),
                .CLKOUT6_DIVIDE(1),
                .CLKOUT6_DUTY_CYCLE(0.5),
                .CLKOUT6_PHASE(0.0),
                
                .DIVCLK_DIVIDE(1),          // Master division value (1-106)
                .REF_JITTER1(0.0),          // Reference input jitter in UI (0.000-0.999)
                .STARTUP_WAIT("FALSE"),      // Delays DONE until MMCM is locked (FALSE, TRUE)
                .IS_CLKIN1_INVERTED(1'b1),  // Optional inversion for CLKIN1
                .IS_PWRDWN_INVERTED(1'b0),  // Optional inversion for PWRDWN
                .IS_RST_INVERTED(1'b1)     // Optional inversion for RST
            ) dco_mmcm_inst (
                // Clock Outputs
                .CLKOUT0(dco_for_serdes),     // 1-bit output: CLKOUT0 (inverted)
                .CLKOUT1(dco_div4),     // 1-bit output: CLKOUT1 (div4)
                .CLKOUT2(),                 // 1-bit output: CLKOUT2 (unused)
                .CLKOUT3(),                 // 1-bit output: CLKOUT3 (unused)
                .CLKOUT4(),                 // 1-bit output: CLKOUT4 (unused)
                .CLKOUT5(),                 // 1-bit output: CLKOUT5 (unused)
                .CLKOUT6(),                 // 1-bit output: CLKOUT6 (unused)
                
                // Feedback Clocks
                .CLKFBOUT(mmcm_feedback),   // 1-bit output: Feedback clock
                .CLKFBOUTB(),               // 1-bit output: Inverted CLKFBOUT (unused)
                
                // Status Ports
                .LOCKED(),       // 1-bit output: LOCK
                
                // Clock Inputs
                .CLKIN1(dco_bufg),          // 1-bit input: Clock
                
                // Control Ports
                .PWRDWN(1'b0),              // 1-bit input: Power-down
                .RST(rstn),                // 1-bit input: Reset
                
                // Feedback Clocks
                .CLKFBIN(mmcm_feedback)     // 1-bit input: Feedback clock
            );
        end
        else begin
            MMCME4_BASE #(
                .BANDWIDTH("OPTIMIZED"),     // Jitter programming (OPTIMIZED, HIGH, LOW)
                .CLKFBOUT_MULT_F(4.0),      // Multiply value for all CLKOUT (2.000-64.000)
                .CLKFBOUT_PHASE(0.0),       // Phase offset in degrees of CLKFB
                .CLKIN1_PERIOD(4.17),       // Input clock period in ns 
                
                // CLKOUT0 configuration - Inverted version of dco
                .CLKOUT0_DIVIDE_F(4.0),     // Divide amount for CLKOUT0 (1.000-128.000)
                .CLKOUT0_DUTY_CYCLE(0.5),   // Duty cycle for CLKOUT0 (0.01-0.99)
                .CLKOUT0_PHASE(0.0),      // Phase offset for CLKOUT0 (-360.000-360.000) - 180° for inversion
                
                // CLKOUT1 configuration - Divided by 4 version of dco
                .CLKOUT1_DIVIDE(16),        // Divide amount for CLKOUT1 (1-128)
                .CLKOUT1_DUTY_CYCLE(0.5),   // Duty cycle for CLKOUT1 (0.01-0.99)
                .CLKOUT1_PHASE(0.0),        // Phase offset for CLKOUT1 (-360.000-360.000)
                
                // Unused outputs
                .CLKOUT2_DIVIDE(1),
                .CLKOUT2_DUTY_CYCLE(0.5),
                .CLKOUT2_PHASE(0.0),
                .CLKOUT3_DIVIDE(1),
                .CLKOUT3_DUTY_CYCLE(0.5),
                .CLKOUT3_PHASE(0.0),
                .CLKOUT4_DIVIDE(1),
                .CLKOUT4_DUTY_CYCLE(0.5),
                .CLKOUT4_PHASE(0.0),
                .CLKOUT5_DIVIDE(1),
                .CLKOUT5_DUTY_CYCLE(0.5),
                .CLKOUT5_PHASE(0.0),
                .CLKOUT6_DIVIDE(1),
                .CLKOUT6_DUTY_CYCLE(0.5),
                .CLKOUT6_PHASE(0.0),
                
                .DIVCLK_DIVIDE(1),          // Master division value (1-106)
                .REF_JITTER1(0.0),          // Reference input jitter in UI (0.000-0.999)
                .STARTUP_WAIT("FALSE"),      // Delays DONE until MMCM is locked (FALSE, TRUE)
                .IS_CLKIN1_INVERTED(1'b0),  // Optional inversion for CLKIN1
                .IS_PWRDWN_INVERTED(1'b0),  // Optional inversion for PWRDWN
                .IS_RST_INVERTED(1'b1)     // Optional inversion for RST
            ) dco_mmcm_inst (
                // Clock Outputs
                .CLKOUT0(dco_for_serdes),     // 1-bit output: CLKOUT0 (non-inverted)
                .CLKOUT1(dco_div4),     // 1-bit output: CLKOUT1 (div4)
                .CLKOUT2(),                 // 1-bit output: CLKOUT2 (unused)
                .CLKOUT3(),                 // 1-bit output: CLKOUT3 (unused)
                .CLKOUT4(),                 // 1-bit output: CLKOUT4 (unused)
                .CLKOUT5(),                 // 1-bit output: CLKOUT5 (unused)
                .CLKOUT6(),                 // 1-bit output: CLKOUT6 (unused)
                
                // Feedback Clocks
                .CLKFBOUT(mmcm_feedback),   // 1-bit output: Feedback clock
                .CLKFBOUTB(),               // 1-bit output: Inverted CLKFBOUT (unused)
                
                // Status Ports
                .LOCKED(),       // 1-bit output: LOCK
                
                // Clock Inputs
                .CLKIN1(dco_bufg),          // 1-bit input: Clock
                
                // Control Ports
                .PWRDWN(1'b0),              // 1-bit input: Power-down
                .RST(rstn),                // 1-bit input: Reset
                
                // Feedback Clocks
                .CLKFBIN(mmcm_feedback)     // 1-bit input: Feedback clock
            );
        end
    endgenerate

    //buffering dco mmcm outputs
    BUFG dco_for_serdes_bufg_inst (
        .I(dco_for_serdes),
        .O(dco_for_serdes_bufg)
    );

    BUFG dco_div4_bufg_inst (
        .I(dco_div4),
        .O(dco_div4_bufg)
    );

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
                .rstn (rstn),
                .read_en (read_en),

                .din_p (din_p[i]),
                .din_n (din_n[i]),
                .fco_byte (fco_byte_inv),
                .dco (dco_for_serdes_bufg),
                .dco_div4 (dco_div4_bufg),

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