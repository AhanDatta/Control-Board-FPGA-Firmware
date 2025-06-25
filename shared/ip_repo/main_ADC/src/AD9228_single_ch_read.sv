//datasheet: https://www.analog.com/media/en/technical-documentation/data-sheets/ad9228.pdf

//clk is input clock, sampling clock, always on
//csb is to start a command
//FCO is a ready signal
//DCO is clk * 6 (resolution and DDR), data is clocked out on DCO

//differential -> single-ended for DCO, VINA, B, C, D
//ddr shift reg clocked on DCO
// then put into FIFO (with a trigger)

module AD9228_single_ch_read #(
    parameter logic DIN_INVERTED = 0,
    parameter integer FIFO_DEPTH = 2048,
    parameter integer DATA_WIDTH = 12
)(
    //common inputs
    input logic clk,
    input logic refclk_200M,
    input logic rstn,
    input logic read_en, //sync to sampling clock, need to be sync to fco_clk

    //AD9228 inputs
    input logic din_p,
    input logic din_n,
    input logic fco, //inversion handled at earlier stage
    input logic dco, //inversion handled at earlier stage
    input logic dco_div4, //inversion handled at earlier stage

    //FIFO connections
    input logic fifo_rd_en,
    input logic fifo_rd_clk,
    input logic fifo_rstn,
    output logic fifo_not_empty,
    output logic fifo_full,
    output logic [DATA_WIDTH-1:0] fifo_dout
);

    logic din;
    logic dco_div4_rstn;
    logic des_data_valid;
    logic ad9228_read_en_sync;
    logic fifo_rst_sync;
    logic [DATA_WIDTH-1:0] des_data;

    IBUFDS #(
        .DIFF_TERM("TRUE"),     // Enable internal differential termination
        .IOSTANDARD("LVDS")     // Specify the I/O standard as LVDS
    ) din_inst (
        .I(din_p),             // Positive input
        .IB(din_n),            // Negative input
        .O(din)          // Single-ended output
    );
    
    //SERDES + gearbox
    AD9228_core_SERDES #(
        .DIN_INVERTED(DIN_INVERTED)
    ) core_inst (
        //inputs
        .rstn (dco_div4_rstn),
        .refclk_200M (refclk_200M),

        //adc inputs
        .din (din),
        .fco (fco_clk),
        .dco (dco),
        .dco_div4 (dco_div4),

        //outputs
        .des_data (des_data),
        .des_data_valid (des_data_valid)
    );

    //synchronizers
    xpm_cdc_sync_rst #(
        .DEST_SYNC_FF(4),   // DECIMAL; range: 2-10
        .INIT(1),           // DECIMAL; 0=initialize synchronization registers to 0, 1=initialize synchronization
                            // registers to 1
        .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
        .SIM_ASSERT_CHK(0)  // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    ) dco_div4_rst_sync_inst (
        .dest_rst(dco_div4_rstn), // 1-bit output: src_rst synchronized to the destination clock domain. This output
                            // is registered.

        .dest_clk(dco_div4), // 1-bit input: Destination clock.
        .src_rst(rstn)    // 1-bit input: Source reset signal.
    );

    xpm_cdc_sync_rst #(
        .DEST_SYNC_FF(4),   // DECIMAL; range: 2-10
        .INIT(1),           // DECIMAL; 0=initialize synchronization registers to 0, 1=initialize synchronization
                            // registers to 1
        .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
        .SIM_ASSERT_CHK(0)  // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    ) fifo_rst_sync_inst (
        .dest_rst(fifo_rst_sync), // 1-bit output: src_rst synchronized to the destination clock domain. This output
                            // is registered.

        .dest_clk(dco_div4), // 1-bit input: Destination clock.
        .src_rst(~fifo_rstn)    // 1-bit input: Source reset signal.
    );

    xpm_cdc_single #(
        .DEST_SYNC_FF(4),   // DECIMAL; range: 2-10
        .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
        .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .SRC_INPUT_REG(1)   // DECIMAL; 0=do not register input, 1=register input
    )
    ad9228_read_en_sync_inst (
        .dest_out(ad9228_read_en_sync), // 1-bit output: src_in synchronized to the destination clock domain. This output is
                            // registered.

        .dest_clk(dco_div4), // 1-bit input: Clock signal for the destination clock domain.
        .src_clk(clk),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
        .src_in(read_en)      // 1-bit input: Input signal to be synchronized to dest_clk domain.
    );

    logic fifo_wr_rst_busy;
    logic fifo_rd_rst_busy;
    xpm_fifo_async #(
      .CASCADE_HEIGHT(0),        // DECIMAL
      .CDC_SYNC_STAGES(2),       // DECIMAL
      .DOUT_RESET_VALUE("0"),    // String
      .ECC_MODE("no_ecc"),       // String
      .FIFO_MEMORY_TYPE("auto"), // String
      .FIFO_READ_LATENCY(1),     // DECIMAL
      .FIFO_WRITE_DEPTH(FIFO_DEPTH),   // DECIMAL
      .FULL_RESET_VALUE(0),      // DECIMAL
      .PROG_EMPTY_THRESH(10),    // DECIMAL
      .PROG_FULL_THRESH(10),     // DECIMAL
      .RD_DATA_COUNT_WIDTH(1),   // DECIMAL
      .READ_DATA_WIDTH(DATA_WIDTH),      // DECIMAL
      .READ_MODE("std"),         // String
      .RELATED_CLOCKS(0),        // DECIMAL
      .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES("0707"), // String
      .WAKEUP_TIME(0),           // DECIMAL
      .WRITE_DATA_WIDTH(DATA_WIDTH),     // DECIMAL
      .WR_DATA_COUNT_WIDTH(1)    // DECIMAL
   )
   xpm_fifo_async_inst (
      .almost_empty(),   // 1-bit output: Almost Empty : When asserted, this signal indicates that
                                     // only one more read can be performed before the FIFO goes to empty.

      .almost_full(),     // 1-bit output: Almost Full: When asserted, this signal indicates that
                                     // only one more write can be performed before the FIFO is full.

      .data_valid(),       // 1-bit output: Read Data Valid: When asserted, this signal indicates
                                     // that valid data is available on the output bus (dout).

      .dbiterr(),             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
                                     // a double-bit error and data in the FIFO core is corrupted.

      .dout(fifo_dout),                   // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
                                     // when reading the FIFO.

      .empty(~fifo_not_empty),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the
                                     // FIFO is empty. Read requests are ignored when the FIFO is empty,
                                     // initiating a read while empty is not destructive to the FIFO.

      .full(fifo_full),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the
                                     // FIFO is full. Write requests are ignored when the FIFO is full,
                                     // initiating a write when the FIFO is full is not destructive to the
                                     // contents of the FIFO.

      .overflow(),           // 1-bit output: Overflow: This signal indicates that a write request
                                     // (wren) during the prior clock cycle was rejected, because the FIFO is
                                     // full. Overflowing the FIFO is not destructive to the contents of the
                                     // FIFO.

      .prog_empty(),       // 1-bit output: Programmable Empty: This signal is asserted when the
                                     // number of words in the FIFO is less than or equal to the programmable
                                     // empty threshold value. It is de-asserted when the number of words in
                                     // the FIFO exceeds the programmable empty threshold value.

      .prog_full(),         // 1-bit output: Programmable Full: This signal is asserted when the
                                     // number of words in the FIFO is greater than or equal to the
                                     // programmable full threshold value. It is de-asserted when the number of
                                     // words in the FIFO is less than the programmable full threshold value.

      .rd_data_count(), // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
                                     // number of words read from the FIFO.

      .rd_rst_busy(fifo_rd_rst_busy),     // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
                                     // domain is currently in a reset state.

      .sbiterr(),             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
                                     // and fixed a single-bit error.

      .underflow(),         // 1-bit output: Underflow: Indicates that the read request (rd_en) during
                                     // the previous clock cycle was rejected because the FIFO is empty. Under
                                     // flowing the FIFO is not destructive to the FIFO.

      .wr_ack(),               // 1-bit output: Write Acknowledge: This signal indicates that a write
                                     // request (wr_en) during the prior clock cycle is succeeded.

      .wr_data_count(), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
                                     // the number of words written into the FIFO.

      .wr_rst_busy(fifo_wr_rst_busy),     // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                                     // write domain is currently in a reset state.

      .din(des_data),                     // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
                                     // writing the FIFO.

      .injectdbiterr(), // 1-bit input: Double Bit Error Injection: Injects a double bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .injectsbiterr(), // 1-bit input: Single Bit Error Injection: Injects a single bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .rd_clk(fifo_rd_clk),               // 1-bit input: Read clock: Used for read operation. rd_clk must be a free
                                     // running clock.

      .rd_en(fifo_rd_en && !fifo_rd_rst_busy),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
                                     // signal causes data (on dout) to be read from the FIFO. Must be held
                                     // active-low when rd_rst_busy is active high.

      .rst(fifo_rst_sync),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
                                     // unstable at the time of applying reset, but reset must be released only
                                     // after the clock(s) is/are stable.

      .sleep(1'b0),                 // 1-bit input: Dynamic power saving: If sleep is High, the memory/fifo
                                     // block is in power saving mode.

      .wr_clk(dco_div4),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
                                     // free running clock.

      .wr_en(ad9228_read_en_sync && des_data_valid && fifo_rstn && !fifo_wr_rst_busy)  // 1-bit input: Write Enable: If the FIFO is not full, asserting this
                                     // signal causes data (on din) to be written to the FIFO. Must be held
                                     // active-low when rst or wr_rst_busy is active high.

   );

endmodule