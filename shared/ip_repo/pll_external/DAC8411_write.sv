//Datasheet: https://www.ti.com/lit/ds/symlink/dac8311.pdf?HQS=dis-dk-null-digikeymode-dsf-pf-null-wwe&ts=1730659513011&ref_url=https%253A%252F%252Fwww.ti.com%252Fgeneral%252Fdocs%252Fsuppproductinfo.tsp%253FdistId%253D10%2526gotoUrl%253Dhttps%253A%252F%252Fwww.ti.com%252Flit%252Fgpn%252Fdac8311

module DAC8411_write #(
    parameter DAC_WIDTH = 16
) (
    input logic [DAT_WIDTH-1:0] data_in;
    input logic new_data_flag;
    input logic aresetn; //async, as allowed by the syncn interupt feature
    input logic clk; //same freq as AD4008
    output logic sclk; //write clock
    output logic serial_data_out;
    output logic syncn; //Acts as active-low cnv signal, as detailed in datasheet above
);
    typedef enum { RESET, IDLE, INIT_CONVERSION, WRITE_DATA } state_t;

    state_t state;
    logic [DAC_WIDTH-1:0] latched_data_in;
    logic latched_new_data_flag;
    logic sclk_enable;
    integer write_counter;

    assign sclk = clk;

    always_ff @(posedge new_data_flag or negedge aresetn) begin
        if (!aresetn) begin
            latched_data_in <= '0;
            latched_new_data_flag <= 0;
        end
        else begin
            latched_data_in <= data_in;
            latched_new_data_flag <= 1;
        end
    end

    //main state machine
    always_ff @(negedge clk or negedge aresetn) begin
        if (!aresetn) begin
            syncn <= 1; //syncn interupt
            serial_data_out <= 0;
            state <= RESET;
        end
        else begin
            case (state)
                RESET:
                begin
                    state <= IDLE;
                    syncn <= 1;
                    serial_data_out <= 0;
                end

                IDLE:
                begin
                    syncn <= 1;
                    serial_data_out <= 0;
                    if (latched_new_data_flag) begin
                        state <= INIT_CONVERSION;
                        latched_new_data_flag <= 0;
                    end
                    else begin
                        state <= IDLE;
                    end
                end

                INIT_CONVERSION:
                begin
                    syncn <= 0;
                    serial_data_out <= 0; 
                    write_counter <= DAC_WIDTH+1; //+2 from the DAC width for first 2 Mode bits
                    state <= WRITE_DATA;
                end

                WRITE_DATA:
                begin
                    if (write_counter == DAC_WIDTH+1 || write_counter == DAC_WIDTH) begin //sets mode to normal
                        serial_data_out <= 0;
                    end
                    else begin
                        serial_data_out <= latched_data_in[write_counter];
                    end

                    write_counter <= write_counter - 1;
                    if (write_counter == 0) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end 
endmodule