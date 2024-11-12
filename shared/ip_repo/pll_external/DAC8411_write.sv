//Datasheet: https://www.ti.com/lit/ds/symlink/dac8311.pdf?HQS=dis-dk-null-digikeymode-dsf-pf-null-wwe&ts=1730659513011&ref_url=https%253A%252F%252Fwww.ti.com%252Fgeneral%252Fdocs%252Fsuppproductinfo.tsp%253FdistId%253D10%2526gotoUrl%253Dhttps%253A%252F%252Fwww.ti.com%252Flit%252Fgpn%252Fdac8311

module DAC8411_write #(
    parameter DAC_WIDTH = 16
) (
    input logic [DAT_WIDTH-1:0] data_in;
    input logic aresetn; //async, as allowed by the syncn interupt feature
    input logic clk; //same freq as AD4008
    output logic sclk; //write clock
    output logic serial_data_out;
    output logic syncn; //Acts as active-low cnv signal, as detailed in datasheet above
);
    typedef enum { RESET, IDLE, INIT_CONVERSION, WRITE_DATA } state_t;

    state_t state;
    logic [DAC_WIDTH-1:0] latched_data_in;
    logic [7:0] write_counter;

    assign sclk = ~clk; //since data is read on negedge of sclk, and we want to use negedge clk, we do this inversion


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

                IDLE: //State is here to reset syncn
                begin
                    syncn <= 1;
                    serial_data_out <= 0;
                    state <= INIT_CONVERSION;
                end

                INIT_CONVERSION:
                begin
                    syncn <= 0;
                    serial_data_out <= 0; 
                    write_counter <= DAC_WIDTH + 8 - 1; //need 24 clk cycles to complete a full transaction
                    latched_data_in <= data_in;
                    state <= WRITE_DATA;
                end

                WRITE_DATA:
                begin
                    if (write_counter == DAC_WIDTH+7 || write_counter == DAC_WIDTH+6) begin //sets DAC mode to normal, as per datasheet
                        serial_data_out <= 0;
                    end
                    else if (write_counter > 8'd5) begin
                        serial_data_out <= latched_data_in[write_counter - 6]; //start sending data on 21st bit
                    end
                    else begin //last 6 bits are ignored
                        serial_data_out <= 0;
                    end

                    //handles indexing and reseting syncn
                    write_counter <= write_counter - 1;
                    if (write_counter == 0) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end 
endmodule