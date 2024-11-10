`timescale 1ns/1ps

module AD4008_emulator #(
    parameter ADC_WIDTH = 16
)(
    input logic cnv,
    input logic sck,
    output logic sdo
);

    logic [ADC_WIDTH-1:0] data;
    logic [ADC_WIDTH-1:0] sck_counter;
    logic ready_for_readout;
    assign data = 'b10101010_10101010;

    always @(posedge cnv) begin //simulates doing the conversion
        sck_counter = '0;
        sdo = 1;
        #290; //typical t_conv
        if (!cnv) begin
            ready_for_readout = 1;
            sdo = 0; //send the busy signal
        end
    end

    always_ff @(negedge sck) begin
        if (ready_for_readout) begin
            if (sck_counter >= ADC_WIDTH) begin //have read out all data
                ready_for_readout <= 0;
                sdo <= 1;
            end
            else begin
                sdo <= data[ADC_WIDTH - sck_counter - 1];
            end
        end
    end


endmodule