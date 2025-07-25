module SPI_read #(
    parameter REG_WIDTH = 8
) (
    input logic rstn,
    input logic clk,
    input logic serial_in,
    input logic new_command,
    input logic [7:0] num_regs_to_read,
    input logic [REG_WIDTH-1:0] start_read_register_addr,
    input logic is_write,

    output logic [REG_WIDTH-1:0] data_read_from_reg,
    output logic serial_out,
    output logic spi_clk_en,
    output logic read_complete,
    output logic read_one_byte_complete //for the mux
);

    typedef enum logic [1:0] {
        IDLE,
        SEND_ADDRESS,
        READ_DATA,
        COMPLETE
    } spi_state_t;

    spi_state_t current_state;
    logic prev_new_command;
    logic [11:0] bit_counter;
    logic [REG_WIDTH-1:0] start_addr;
    logic [7:0] num_regs;
    logic [REG_WIDTH-1:0] serial_in_buffer;

    //main state machine
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            current_state <= IDLE;
            prev_new_command <= 1'b0;
            spi_clk_en <= 1'b0;
            serial_in_buffer <= '0;
            read_complete <= 1'b0;
            read_one_byte_complete <= 1'b0;
            bit_counter <= '0;
            serial_out <= 1'b0;
        end
        else begin
            prev_new_command <= new_command;
            case (current_state) 

                IDLE: begin
                    bit_counter <= '0;
                    read_complete <= 1'b0;
                    read_one_byte_complete <= 1'b0;
                    spi_clk_en <= 1'b0;
                    if (new_command && ~prev_new_command && ~is_write) begin
                        //capture input parameters
                        num_regs <= num_regs_to_read;
                        start_addr <= start_read_register_addr;
                        current_state <= SEND_ADDRESS;
                    end
                end 

                SEND_ADDRESS: begin
                    //shift out address bits
                    if (bit_counter < (REG_WIDTH)) begin
                        serial_out <= start_addr[REG_WIDTH - 1 - bit_counter];
                        bit_counter <= bit_counter + 1;
                        spi_clk_en <= 1'b1;
                    end
                    else begin //transitions and sends the last bit at the same time
                        serial_out <= 1'b0;
                        bit_counter <= '0;
                        current_state <= READ_DATA;
                    end
                end

                READ_DATA: begin
                    if (bit_counter < (num_regs*REG_WIDTH)-1) begin
                        if (bit_counter % 8 == 0 && bit_counter != 8'b0) begin //signals to put the read byte into FIFO
                            data_read_from_reg <= serial_in_buffer;
                            read_one_byte_complete <= 1'b1;
                        end
                        else begin 
                            read_one_byte_complete <= 1'b0;
                        end
                        serial_out <= 1'b0;
                        serial_in_buffer <= {serial_in_buffer[REG_WIDTH - 2 : 0], serial_in};
                        bit_counter <= bit_counter + 1;
                    end
                    else begin
                        serial_in_buffer <= {serial_in_buffer[REG_WIDTH - 2 : 0], serial_in}; //catches the last bit
                        spi_clk_en <= 1'b0;
                        current_state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    data_read_from_reg <= serial_in_buffer;
                    read_one_byte_complete <= 1'b1;
                    read_complete <= 1'b1;
                    serial_out <= 1'b0;
                    current_state <= IDLE;
                end

            endcase
        end
    end    

endmodule