module AD4008_emulator #(
    parameter ADC_WIDTH = 16
)(
    input logic [ADC_WIDTH-1:0] fake_data,
    input logic cnv,
    input logic sck,
    output logic sdo
);

    logic [ADC_WIDTH-1:0] sck_counter;
    logic ready_for_readout;

    always @(posedge cnv) begin //simulates doing the conversion
        sck_counter <= '0;
        sdo <= 1;
        #290; //typical t_conv
        if (!cnv) begin
            ready_for_readout <= 1;
            sdo <= 0; //send the busy signal
        end
    end

    always @(negedge sck) begin
        if (ready_for_readout) begin
            if (sck_counter >= ADC_WIDTH) begin //have read out all data
                ready_for_readout <= 0;
                sdo <= 1;
            end
            else begin
                sdo <= fake_data[ADC_WIDTH - sck_counter - 1]; //msb to lsb
                sck_counter <= sck_counter + 1;
            end
        end
    end


endmodule