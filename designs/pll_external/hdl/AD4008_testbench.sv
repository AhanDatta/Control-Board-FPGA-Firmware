`timescale 1ns/1ps

module AD4008_testbench #(
    parameter ADC_WIDTH = 16
)();

    logic DBG_READOUT = 1;

    logic sdo;
    logic cnv;
    logic sck;
    logic [ADC_WIDTH-1:0] fake_data;

    logic clk;
    logic aresetn;
    logic new_data_flag;
    logic [ADC_WIDTH-1:0] amplified_data;

    always #10 clk = ~clk;

    AD4008_read AD4008_read_inst (
        .clk (clk),
        .aresetn(aresetn),
        .data_in (sdo),
        .cnv (cnv),
        .sck (sck),
        .new_data_flag (new_data_flag),
        .amplified_data (amplified_data)
    );

    AD4008_emulator AD4008_emulator_inst (
        .fake_data (fake_data),
        .cnv (cnv),
        .sck (sck),
        .sdo (sdo)
    );

    //external reseting the driver
    task ext_reset ();
        aresetn = 0;
        @(posedge clk);
        @(negedge clk);
        aresetn = 1;

        $display("External Reset -------------------------------------------------------------------------------------------------------------------------");
    endtask

    //For dbg
    always @(posedge clk, negedge clk) begin
    if (DBG_READOUT) begin
        $display(
        "time: %0d, clk: %0b, aresetn: %0b, internal_data: %0b, amplified_data: %0b, new_data_flag: %0b, cnv: %0b, sdo: %0b, sck: %0b",
        $time, clk, aresetn, AD4008_read_inst.raw_data, amplified_data, new_data_flag, cnv, sdo, sck);

        if(clk == 0) begin
        $display("--------------------------------------------------------------------------------------------------------------------------------------------------");
        end
    end
    end

    initial begin
        //resetting and initial values
        fake_data = 'b10101010_10101010;
        clk = 1;
        aresetn = 1;
        #50;
        ext_reset();

        #650;
      	fake_data = 'b00000000_11110000;
      	#650;
    end

endmodule