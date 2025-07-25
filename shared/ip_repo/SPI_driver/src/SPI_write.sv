module SPI_write #(
    parameter REG_WIDTH = 8,
    parameter MSG_LEN = 2
)(
    input logic rstn,
    input logic clk,
    input logic serial_in,
    input logic new_command,
    input logic [REG_WIDTH-1:0] register_addr,
    input logic [REG_WIDTH*(MSG_LEN-1)-1:0] write_data,
    input logic is_write,

    output logic [REG_WIDTH*(MSG_LEN-1)-1:0] data_read_from_reg,
    output logic serial_out,
    output logic spi_clk_en,
    output logic transaction_complete
);

    typedef enum logic [1:0] {
        IDLE,
        SEND_ADDRESS,
        TRANSFER_DATA,
        COMPLETE
    } spi_state_t;

    //internal signals
    spi_state_t current_state;
    logic prev_new_command;
    logic spi_clk_en;
    logic [7:0] bit_counter;
    logic [REG_WIDTH-1:0] addr;
    logic [REG_WIDTH*(MSG_LEN-1)-1:0] data_to_write;
    logic [REG_WIDTH*(MSG_LEN-1)-1:0] serial_in_buffer;

    //main state machine
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            current_state <= IDLE;
            serial_out <= 1'b0;
            data_read_from_reg <= '0;
            serial_in_buffer <= '0;
            bit_counter <= '0;
            transaction_complete <= 1'b0;
            prev_new_command <= 1'b0;
            spi_clk_en <= 1'b0;
        end
        else begin
            prev_new_command <= new_command;
            case (current_state)

                IDLE: begin
                    bit_counter <= '0;
                    transaction_complete <= 1'b0;
                    spi_clk_en <= 1'b0;
                    if (new_command && ~prev_new_command && is_write) begin
                        //capture input parameters
                        addr <= register_addr;
                        data_to_write <= write_data;
                        current_state <= SEND_ADDRESS;
                    end
                end

                SEND_ADDRESS: begin
                    //shift out address bits
                    if (bit_counter < (REG_WIDTH-1)) begin
                        serial_out <= addr[REG_WIDTH - 1 - bit_counter];
                        bit_counter <= bit_counter + 1;
                        spi_clk_en <= 1'b1;
                    end
                    else begin //transitions and sends the last bit at the same time
                        serial_out <= addr[0];
                        bit_counter <= '0;
                        current_state <= TRANSFER_DATA;
                    end
                end

                TRANSFER_DATA: begin
                    if (bit_counter < REG_WIDTH * (MSG_LEN-1)) begin
                        serial_out <= data_to_write[(MSG_LEN-1)*REG_WIDTH - 1 - bit_counter];

                        if (bit_counter != '0) begin //reading is 1 cycle delayed
                            serial_in_buffer <= {serial_in_buffer[REG_WIDTH * (MSG_LEN-1) - 2 : 0], serial_in};
                        end

                        bit_counter <= bit_counter + 1;
                    end
                    else begin
                        serial_in_buffer <= {serial_in_buffer[REG_WIDTH * (MSG_LEN-1) - 2 : 0], serial_in}; //catches the last bit
                        spi_clk_en <= 1'b0;
                        current_state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    data_read_from_reg <= serial_in_buffer;
                    transaction_complete <= 1'b1;
                    serial_out <= 1'b0;
                    current_state <= IDLE;
                end
            endcase
        end
    end
endmodule