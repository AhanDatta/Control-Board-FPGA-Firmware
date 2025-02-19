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
    parameter integer DATA_WIDTH = 12
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
    input logic fifo_rd_clk,
    output logic fifo_not_empty,
    output logic fifo_full,
    output logic [DATA_WIDTH-1:0] fifo_dout
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
        .clk (clk),

        //adc inputs
        .din (din),
        .fco (fco),
        .dco (dco),

        //outputs
        .des_data (des_data),
        .read_complete (read_complete)
    );

    xpm_fifo_async #(
      .CASCADE_HEIGHT(0),        // DECIMAL
      .CDC_SYNC_STAGES(2),       // DECIMAL
      .DOUT_RESET_VALUE("0"),    // String
      .ECC_MODE("no_ecc"),       // String
      .FIFO_MEMORY_TYPE("auto"), // String
      .FIFO_READ_LATENCY(1),     // DECIMAL
      .FIFO_WRITE_DEPTH(2048),   // DECIMAL
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

      .empty(),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the
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

      .rd_rst_busy(),     // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
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

      .wr_rst_busy(),     // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                                     // write domain is currently in a reset state.

      .din(des_data),                     // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
                                     // writing the FIFO.

      .injectdbiterr(), // 1-bit input: Double Bit Error Injection: Injects a double bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .injectsbiterr(), // 1-bit input: Single Bit Error Injection: Injects a single bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .rd_clk(fifo_rd_clk),               // 1-bit input: Read clock: Used for read operation. rd_clk must be a free
                                     // running clock.

      .rd_en(fifo_rd_en),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
                                     // signal causes data (on dout) to be read from the FIFO. Must be held
                                     // active-low when rd_rst_busy is active high.

      .rst(~rstn),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
                                     // unstable at the time of applying reset, but reset must be released only
                                     // after the clock(s) is/are stable.

      .sleep(),                 // 1-bit input: Dynamic power saving: If sleep is High, the memory/fifo
                                     // block is in power saving mode.

      .wr_clk(clk),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
                                     // free running clock.

      .wr_en(read_complete)                  // 1-bit input: Write Enable: If the FIFO is not full, asserting this
                                     // signal causes data (on din) to be written to the FIFO. Must be held
                                     // active-low when rst or wr_rst_busy is active high.

   );

endmodule