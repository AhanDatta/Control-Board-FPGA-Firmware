module SPI_driver #(
    parameter REG_WIDTH = 8
)(
    //common inputs
    input logic rstn,
    input logic clk,
    input logic serial_in,
    input logic new_command,

    //write inputs
    input logic [REG_WIDTH-1:0] write_register_addr,
    input logic [REG_WIDTH-1:0] write_data,

    //read inputs
    input logic [7:0] num_regs_to_read,
    input logic [7:0] start_read_register_addr,

    //mux inputs
    input logic is_write,

    //outputs
    output logic [REG_WIDTH-1:0] data_read_from_reg,
    output logic serial_out,
    output logic spi_clk,
    output logic write_complete,
    output logic read_complete
);

    SPI_write write (
        //inputs
        .rstn (rstn),
        .clk (clk),
        .serial_in (serial_in),
        .new_command (new_command),
        .register_addr (write_register_addr),
        .write_data (write_data),

        //outputs
        .data_read_from_reg (data_read_from_reg),
        .serial_out (serial_out),
        .spi_clk (spi_clk),
        .transaction_complete (write_complete)
    );

    //put read block here

    //put mux here

endmodule