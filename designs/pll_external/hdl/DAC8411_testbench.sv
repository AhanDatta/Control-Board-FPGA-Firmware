//Must be greater than 1ps/ps
`timescale 1ns/1ps

module DAC8411_testbench#(
    parameter DAC_WIDTH = 16
)();
    logic DBG_READOUT = 1;

    logic [DAC_WIDTH-1:0] amplified_adc_counts;
    logic aresetn;
    logic clk;

    logic sclk;
    logic serial_adc_counts;
    logic syncn; 

    DAC8411_write DAC8411_write_inst (
        .data_in (amplified_adc_counts),
        .aresetn (aresetn),
        .clk (clk),
        .sclk (sclk),
        .serial_data_out (serial_adc_counts),
        .syncn (syncn)
    );

    always #10 clk = ~clk;

    always @(posedge clk, negedge clk) begin
    if (DBG_READOUT) begin
        $display(
        "time: %0d, clk: %0b, aresetn: %0b, data_in: %0b, sclk: %0b, serial_out: %0b, syncn: %0b",
        $time, clk, aresetn, amplified_adc_counts, sclk, serial_adc_counts, syncn);

        if(clk == 0) begin
        $display("--------------------------------------------------------------------------------------------------------------------------------------------------");
        end
    end
    end

    //external reseting the driver
    task ext_reset ();
        aresetn = 0;
        @(posedge clk);
        @(negedge clk);
        aresetn = 1;

        $display("External Reset -------------------------------------------------------------------------------------------------------------------------");
    endtask

    initial begin
        //resetting and initial values
        amplified_adc_counts = 'b10101010_10101010;
        clk = 1;
        aresetn = 1;
        #50;
        ext_reset();

    end

endmodule