module SPI_driver #(
    parameter REG_WIDTH = 8
)(
    //common inputs
    input logic rstn,
    input logic clk,
    input logic serial_in,
    input logic new_command,
    input logic is_write,

    //write inputs
    input logic [REG_WIDTH-1:0] write_register_addr,
    input logic [REG_WIDTH-1:0] write_data,

    //read inputs
    input logic [7:0] num_regs_to_read,
    input logic [7:0] start_read_register_addr,

    //outputs
    output logic [REG_WIDTH-1:0] data_read_from_reg,
    output logic serial_out,
    output logic spi_clk,
    output logic write_complete,
    output logic read_complete,
    output logic fifo_wr_en
);
    logic spi_clk_en;

    //write outputs
    logic [REG_WIDTH-1:0] data_read_during_write;
    logic write_serial_out;
    logic write_spi_clk_en;

    //read outputs
    logic [REG_WIDTH-1:0] data_read_during_read;
    logic read_serial_out;
    logic read_spi_clk_en;
    logic read_one_byte_complete;

    SPI_write write (
        //inputs
        .rstn (rstn),
        .clk (clk),
        .serial_in (serial_in),
        .new_command (new_command),
        .register_addr (write_register_addr),
        .write_data (write_data),
        .is_write (is_write),

        //outputs
        .data_read_from_reg (data_read_during_write),
        .serial_out (write_serial_out),
        .spi_clk_en (write_spi_clk_en),
        .transaction_complete (write_complete)
    );

    SPI_read read (
        //inputs
        .rstn (rstn),
        .clk (clk),
        .serial_in (serial_in),
        .new_command (new_command),
        .num_regs_to_read (num_regs_to_read),
        .start_read_register_addr (start_read_register_addr),
        .is_write (is_write),

        //outputs
        .data_read_from_reg (data_read_during_read),
        .serial_out (read_serial_out),
        .spi_clk_en (read_spi_clk_en),
        .read_complete (read_complete),
        .read_one_byte_complete (read_one_byte_complete)
    );

    SPI_output_mux mux (
        //common inputs
        .rstn (rstn),
        .is_write (is_write),

        //write inputs
        .data_read_during_write (data_read_during_write),
        .write_serial_out (write_serial_out),
        .write_spi_clk_en (write_spi_clk_en),
        .write_complete (write_complete),

        //read inputs
        .data_read_during_read (data_read_during_read),
        .read_serial_out (read_serial_out),
        .read_spi_clk_en (read_spi_clk_en),
        .read_one_byte_complete (read_one_byte_complete),

        //final outputs
        .data_read_from_reg (data_read_from_reg),
        .serial_out (serial_out),
        .spi_clk_en (spi_clk_en),
        .fifo_wr_en (fifo_wr_en)
    );

    //clock generation
    BUFGCE #(
      .CE_TYPE("SYNC"),               // ASYNC, HARDSYNC, SYNC
      .IS_CE_INVERTED(1'b0),          // Programmable inversion on CE
      .IS_I_INVERTED(1'b1),           // Programmable inversion on I
      .SIM_DEVICE("ULTRASCALE_PLUS")  // ULTRASCALE, ULTRASCALE_PLUS
   )
   spi_clk_gen (
      .O(spi_clk),   // 1-bit output: Buffer
      .CE(rstn && spi_clk_en), // 1-bit input: Buffer enable
      .I(clk)    // 1-bit input: Buffer
   );

endmodule