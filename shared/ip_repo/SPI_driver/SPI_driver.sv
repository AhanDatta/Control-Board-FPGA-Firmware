//Take in cmnd from IPIF (AXI) interface
/*
Create IPIF struct with all values to be written
*/
//Update state machine
/*
detect new IPIF cmnd, by setting one of the bits as a self-reseting flag
Do cmnd
*/
//Send out command

module SPI_driver #(
    parameter REG_WIDTH = 8,
    parameter MSG_LEN = 2
)(
    input logic rstn,
    input logic clk,
    input logic serial_in,
    input logic new_command,
    input logic [REG_WIDTH-1:0] register_addr,
    input logic [REG_WIDTH*(MSG_LEN-1)-1:0] write_data,
    output logic [REG_WIDTH*(MSG_LEN-1)-1:0] data_read_from_reg,
    output logic serial_out,
    output logic spi_clk
);
    //working address and write data
    logic [REG_WIDTH*(MSG_LEN-1) - 1:0] data_to_write;
    logic [REG_WIDTH*(MSG_LEN-1) - 1:0] serial_in_deserializer;
    logic [REG_WIDTH-1:0] addr;
    logic [7:0] clk_counter;
    logic spi_clk_enable;

    //on new instruction, load data
    always_ff @(posedge new_command or negedge rstn) begin
        if (!rstn) begin
            data_to_write <= '0;
            addr <= '0;
            clk_counter <= REG_WIDTH*MSG_LEN + 1;
        end
        else begin
            data_to_write <= write_data;
            addr <= register_addr;
            clk_counter <= '0;
        end
    end

    //Starts the clock when we want to send a message
    always_comb begin
        if (spi_clk_enable) begin
            spi_clk = ~clk;
        end
        else  begin
            spi_clk = 0;
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            spi_clk_enable <= 0;
            serial_out <= 0;
        end
        else if (clk_counter < REG_WIDTH) begin //sending the address
            spi_clk_enable <= 1;
            serial_out <= addr[clk_counter];
            clk_counter <= clk_counter + 1;
        end
        else if (clk_counter < REG_WIDTH*MSG_LEN) begin
            spi_clk_enable <= 1;
            serial_out <= data_to_write[clk_counter-REG_WIDTH];
            serial_in_deserializer[clk_counter-REG_WIDTH] <= serial_in; 
            clk_counter <= clk_counter + 1;
        end
        else if (clk_counter == REG_WIDTH*MSG_LEN + 1) begin
            spi_clk_enable <= 0;
            serial_out <= 0;
        end
        else begin
            spi_clk_enable <= 0;
            serial_out <= 0;
        end
    end

endmodule