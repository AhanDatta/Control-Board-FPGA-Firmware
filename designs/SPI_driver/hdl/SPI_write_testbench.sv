//Must be greater than 1ps/ps
`timescale 1ns/1ps

module SPI_write_testbench ();

    //clocks and reset
    logic clk; //fpga
    logic chip_clk; //on_chip ~40 MHz
    logic fclk; //on_chip fast
    logic fpga_rstn;
    logic chip_rstn;

    always #25 clk = ~clk;
    always #20 chip_clk = ~chip_clk;
    always #0.2 fclk = ~fclk;

    //inputs to control
    logic new_command;
    logic [7:0] addr;
    logic [7:0] write_data;

    //input to peripheral
    logic [7:0] pll_locked;

    //inputs to each channel
    //counts held in each channel
    logic [9:0] CA0, CA1, CA2, CA3, CA4, CA5, CA6, CA7;
    logic [9:0] CB0, CB1, CB2, CB3, CB4, CB5, CB6, CB7;
    logic [9:0] CC0, CC1, CC2, CC3, CC4, CC5, CC6, CC7;
    logic [9:0] CD0, CD1, CD2, CD3, CD4, CD5, CD6, CD7;
    logic [9:0] CE0, CE1, CE2, CE3, CE4, CE5, CE6, CE7;
    logic DISCRIMINATOR_OUTPUT;

    //outputs of control
    logic [7:0] data_read_from_reg;
    logic transaction_complete;

    //output from peripheral
    logic clk_enable;
    logic [7:0] trigger_channel_mask;
    logic [7:0] vco_control;
    logic [7:0] pll_div_ratio;
    logic [7:0] slow_mode;

    //outputs from each channel
     logic [7:0] STOP_REQUEST;
     logic [7:0] TRIGGERA;
     logic [7:0] TRIGGERB;
     logic [7:0] TRIGGERC;
     logic [7:0] TRIGGERD;
     logic [7:0] TRIGGERE;
     logic [7:0] TRIGGERAC;
     logic [7:0] TRIGGERBC;
     logic [7:0] TRIGGERCC;
     logic [7:0] TRIGGERDC;

    //wires to peripheral from control
    logic pico;
    logic spi_clk;
    
    //wires from serial_out_mux to control
    logic poci;

    //internal wires between peripheral and each channel
    logic [7:0] disc_polarity;
    logic [7:0] mode;

    //internal wires between peripheral and every channel
    logic inst_rst;
    logic inst_readout;
    logic inst_start;
    logic [2:0] select_reg;
    logic [7:0] trig_delay;

    //internal wires to serial_out_mux
    logic [7:0] channel_serial_out; //from channel
    logic [7:0] mux_control_signal; //from peripheral
    logic wr_serial_out; //from peripheral

    //instantiating all the components
    SPI_write control (
        //inputs
        .rstn (fpga_rstn),
        .clk (clk),
        .serial_in (poci),
        .new_command (new_command),
        .register_addr (addr),
        .write_data (write_data),
        
        //outputs
        .data_read_from_reg (data_read_from_reg),
        .serial_out (pico),
        .spi_clk (spi_clk),
        .transaction_complete (transaction_complete)
    );

    SPI peripheral (
        //inputs
        .serial_in (pico),
        .sclk (spi_clk),
        .pll_locked (pll_locked),
        .iclk (chip_clk),
        .rstn (chip_rstn),

        //outputs
        .clk_enable (clk_enable),
        .inst_rst (inst_rst),
        .inst_readout (inst_readout),
        .inst_start (inst_start),
        .mux_control_signal (mux_control_signal),
        .select_reg (select_reg),
        .trigger_channel_mask (trigger_channel_mask),
        .mode (mode),
        .disc_polarity (disc_polarity),
        .vco_control (vco_control),
        .pll_div_ratio (pll_div_ratio),
        .slow_mode (slow_mode),
        .trig_delay (trig_delay),
        .serial_out (wr_serial_out)
    );

    serial_out_mux mux (
        //inputs
        .sclk (spi_clk),
        .rstn (chip_rstn),
        .raw_serial_out (channel_serial_out),
        .wr_serial_out (wr_serial_out),
        .mux_control_signal (mux_control_signal),

        //output
        .serial_out (poci)
    );

    //creating the channels
    generate
        for(genvar i = 0; i < 8; i++) begin
            PSEC5_CH_DIGITAL chi (
                //inputs
                .INST_START (inst_start),
                .INST_STOP (inst_stop),
                .INST_READOUT (inst_readout),
                .RSTB (chip_rstn),
                .DISCRIMINATOR_OUTPUT (DISCRIMINATOR_OUTPUT),
                .SPI_CLK (spi_clk),
                .CA (CA0),
                .CB (CB0),
                .CC (CC0),
                .CD (CD0),
                .CE (CE0),
                .MODE (smode_t'(mode[1:0])),
                .DISCRIMINATOR_POLARITY (disc_polarity[0]),
                .SELECT_REG (select_reg),
                .TRIG_DELAY (trig_delay[4:0]),
                .FCLK (fclk),

                //outputs
                .STOP_REQUEST (STOP_REQUEST[i]),
                .TRIGGERA (TRIGGERA[i]),
                .TRIGGERB (TRIGGERB[i]),
                .TRIGGERC (TRIGGERC[i]),
                .TRIGGERD (TRIGGERD[i]),
                .TRIGGERE (TRIGGERE[i]),
                .TRIGGERAC (TRIGGERAC[i]),
                .TRIGGERBC (TRIGGERBC[i]),
                .TRIGGERCC (TRIGGERCC[i]),
                .TRIGGERDC (TRIGGERDC[i]),
                .CNT_SER (channel_serial_out[i])
            );
        end
    endgenerate

    task fpga_reset ();
        fpga_rstn <= 1'b1;
        @(posedge clk);
        @(negedge clk);
        fpga_rstn <= 1'b0;
        @(posedge clk);
        @(negedge clk);
        fpga_rstn <= 1'b1;
    endtask

    task chip_reset ();
        chip_rstn <= 1'b1;
        @(posedge clk);
        @(negedge clk);
        chip_rstn <= 1'b0;
        @(posedge clk);
        @(negedge clk);
        chip_rstn <= 1'b1;
    endtask

    task wait_n_clk (int n);
        for (int i = 0; i < n; i++) begin
            @(posedge clk);
            @(negedge clk);
        end 
    endtask


    //START OF SIMULATION   
    initial begin
        //input to channels
        DISCRIMINATOR_OUTPUT = 1'b0;

        //initializing Channel Values, CA-CE
        CA0 <= 10'b0000000011;
        CB0 <= 10'b0011111111;
        CC0 <= 10'b1111000000;
        CD0 <= 10'b0000001111;
        CE0 <= 10'b1111111100;

        CA1 <= 10'b0000010000;
        CB1 <= 10'b0000100000;
        CC1 <= 10'b0001000000;
        CD1 <= 10'b0010000000;
        CE1 <= 10'b0100000000;

        CA2 <= 10'b1111111111;
        CB2 <= 10'b1111100000;
        CC2 <= 10'b0000011111;
        CD2 <= 10'b1111000011;
        CE2 <= 10'b1010101010;

        CA3 <= 10'b1010100101;
        CB3 <= 10'b1001010101;
        CC3 <= 10'b0010011011;
        CD3 <= 10'b0100001111;
        CE3 <= 10'b0100100111;

        CA4 <= 10'b0011101011;
        CB4 <= 10'b0101010101;
        CC4 <= 10'b0011010111;
        CD4 <= 10'b1111011101;
        CE4 <= 10'b1111101110;

        CA5 <= 10'b0101111010;
        CB5 <= 10'b0000010001;
        CC5 <= 10'b0101000100;
        CD5 <= 10'b0010011010;
        CE5 <= 10'b0101000010;

        CA6 <= 10'b0010010010;
        CB6 <= 10'b1001010001;
        CC6 <= 10'b0100110010;
        CD6 <= 10'b0101001101;
        CE6 <= 10'b1000101010;

        CA7 <= 10'b1001001001;
        CB7 <= 10'b1001010101;
        CC7 <= 10'b0101010011;
        CD7 <= 10'b1001010101;
        CE7 <= 10'b0101010100;

        //input to peripheral
        pll_locked <= 8'b00000000;

        //initializing input to control
        new_command <= 1'b0;
        addr <= 8'b0;
        write_data <= 8'b0;

        //initializing resets and clocks
        fpga_rstn <= 1'b1;
        chip_rstn <= 1'b1;
        clk <= 1'b0;
        chip_clk <= 1'b0;
        fclk <= 1'b0;

        //doing resets
        fpga_reset();
        chip_reset();

       //writing to tcm
       addr <= 8'b0000_0001; //address for tcm
       write_data <= 8'b1010_1010;
       new_command <= 1'b1;

       wait_n_clk(2);
       new_command <= 0'b0;

       //waiting for transaction to finish
       @(posedge transaction_complete)

       //waiting for a reset
       wait_n_clk(10);

       //writing to tcm
       addr <= 8'b0000_0010; //address 3
       write_data <= 8'b0000_0010;
       new_command <= 1'b1; //readout

       wait_n_clk(2);
       new_command <= 0'b0;
       
       //waiting for transaction to finish
       @(posedge transaction_complete)
       
       //waiting for a reset
       wait_n_clk(10);

        //sending command to read from register 8
        addr <= 8'b0000_1000;
        write_data <= 8'b0;
        new_command <= 1'b1;

        wait_n_clk(2);
        new_command <= 0'b0;
    end

endmodule