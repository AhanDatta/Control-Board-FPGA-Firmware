// Datasheet: https://www.digikey.com/en/products/detail/analog-devices-inc/LTC2600CGN-TRPBF/960897

/*
IPIF Command to Command LUT:
    0000: WRITE_TO_REG_N,
    0001: POWER_UP_REG_N,
    0010: WRITE_TO_N_POWER_ALL,
    0011: WRITE_TO_N_POWER_N,
    0100: POWER_DOWN_N,
    1111: NO_OPERATION
*/

module LTC2600_write #(
    parameter integer DATA_WIDTH = 16
) (
    input logic rstn,
    input logic clk, //50 MHz

    //instruction inputs
    input logic send_new_cmd,
    input logic [3:0] command,
    input logic [3:0] address,
    input logic [DATA_WIDTH-1:0] data,

    //DAC wires
    output logic sck,
    output logic sdi,
    output logic csb,

    //outputs
    output logic write_complete
);

    typedef enum logic [2:0] {
        IDLE,
        SEND_COMMAND,
        SEND_ADDRESS,
        SEND_DATA,
        COMPLETE
    } state_t;

    state_t state;
    logic prev_send_new_cmd;
    logic [8:0] clk_counter;

    always_comb begin
        if (!rstn) begin
            sck = 1'b0;
        end
        else begin
            sck = clk; //write clock always on, since we have csb
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            prev_send_new_cmd <= 1'b0;
            write_complete <= 1'b0;
            sdi <= 1'b0;
            csb <= 1'b1;
            clk_counter <= 'b0;
        end
        else begin
            prev_send_new_cmd <= send_new_cmd;
            case (state) 
                IDLE: begin
                    write_complete <= 1'b0;
                    if (send_new_cmd & ~prev_send_new_cmd) begin
                        state <= SEND_COMMAND;
                        sdi <= command[3];
                        csb <= 1'b0;
                        clk_counter <= 'b1;
                    end
                    else begin
                        state <= IDLE;
                        sdi <= 1'b0;
                        csb <= 1'b1;
                        clk_counter <= 'b0;
                    end
                end

                SEND_COMMAND: begin
                    write_complete <= 1'b0;
                    csb <= 1'b0;
                    if (clk_counter == 'd4) begin
                        state <= SEND_ADDRESS;
                        sdi <= address[3];
                        clk_counter <= 'b1;
                    end
                    else begin
                        state <= SEND_COMMAND;
                        sdi <= command[3 - clk_counter];
                        clk_counter <= clk_counter + 1;
                    end
                end

                SEND_ADDRESS: begin
                    write_complete <= 1'b0;
                    csb <= 1'b0;
                    if (clk_counter == 'd4) begin
                        state <= SEND_DATA;
                        sdi <= data[DATA_WIDTH - 1];
                        clk_counter <= 'b1;
                    end
                    else begin
                        state <= SEND_ADDRESS;
                        sdi <= address[3 - clk_counter];
                        clk_counter <= clk_counter + 1;
                    end
                end

                SEND_DATA: begin
                    write_complete <= 1'b0;
                    if (clk_counter == DATA_WIDTH) begin
                        state <= COMPLETE;
                        sdi <= 1'b0;
                        clk_counter <= 'b1;
                        csb <= 1'b1;
                    end
                    else begin
                        state <= SEND_DATA;
                        sdi <= data[DATA_WIDTH - 1 -clk_counter];
                        clk_counter <= clk_counter + 1;
                        csb <= 1'b0;
                    end
                end

                COMPLETE: begin
                    state <= IDLE;
                    write_complete <= 1'b1;
                    sdi <= 1'b0;
                    clk_counter <= 'b0;
                    csb <= 1'b1;
                end
            endcase
        end 
    end

endmodule