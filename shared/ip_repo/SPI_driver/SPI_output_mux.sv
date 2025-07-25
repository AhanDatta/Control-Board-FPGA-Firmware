module SPI_output_mux #(
    REG_WIDTH = 8
) (
    input logic rstn,
    input logic is_write,

    //write inputs
    input logic [REG_WIDTH-1:0] data_read_during_write,
    input logic write_serial_out,
    input logic write_spi_clk_en,
    input logic write_complete,

    //read inputs
    input logic [REG_WIDTH-1:0] data_read_during_read,
    input logic read_serial_out,
    input logic read_spi_clk_en,
    input logic read_one_byte_complete,

    //final outputs
    output logic [REG_WIDTH-1:0] data_read_from_reg,
    output logic serial_out,
    output logic spi_clk_en,
    output logic fifo_wr_en
);

    always_comb begin
        if (!rstn) begin
            data_read_from_reg = '0;
            serial_out = 1'b0;
            spi_clk_en = 1'b0;
            fifo_wr_en = 1'b0;
        end
        else begin
            if (is_write) begin
                data_read_from_reg = data_read_during_write;
                serial_out = write_serial_out;
                spi_clk_en = write_spi_clk_en;
                fifo_wr_en = write_complete;
            end
            else begin
                data_read_from_reg = data_read_during_read;
                serial_out = read_serial_out;
                spi_clk_en = read_spi_clk_en;
                fifo_wr_en = read_one_byte_complete;
            end
        end
    end

endmodule