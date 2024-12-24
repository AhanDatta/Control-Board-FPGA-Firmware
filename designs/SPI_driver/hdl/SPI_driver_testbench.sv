`timescale 1ns/1ps

module SPI_driver_testbench ();

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
    logic [7:0] write_addr;
    logic [7:0] write_data;
    logic [7:0] num_regs_to_read;
    logic [7:0] start_read_register_addr;
    logic is_write;

    //input to peripheral
    logic [7:0] pll_locked;

    //inputs to each channel
    //counts held in each channel
    logic [9:0] CA [8];
    logic [9:0] CB [8];
    logic [9:0] CC [8];
    logic [9:0] CD [8];
    logic [9:0] CE [8];
    logic DISCRIMINATOR_OUTPUT;

    //outputs of control
    logic [7:0] data_read_from_reg;
    logic write_complete;
    logic read_complete;
    logic fifo_wr_en;

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
    SPI_driver control (
        //common inputs
        .rstn (fpga_rstn),
        .clk (clk),
        .serial_in (poci),
        .new_command (new_command),

        //write inputs
        .write_register_addr (write_addr),
        .write_data (write_data),

        //read inputs
        .num_regs_to_read (num_regs_to_read),
        .start_read_register_addr (start_read_register_addr),

        //mux input
        .is_write (is_write),
        
        //outputs
        .data_read_from_reg (data_read_from_reg),
        .serial_out (pico),
        .spi_clk (spi_clk),
        .write_complete (write_complete),
        .read_complete (read_complete),
        .fifo_wr_en (fifo_wr_en)
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
                .CA (CA[i]),
                .CB (CB[i]),
                .CC (CC[i]),
                .CD (CD[i]),
                .CE (CE[i]),
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

    task write_to_peripheral (logic [7:0] addr, logic [7:0] data);
        write_addr <= addr;
        write_data <= data;
        num_regs_to_read <= '0;
        start_read_register_addr <= '0;
        is_write <= 1'b1;
        new_command <= 1'b1;

        wait_n_clk(2);
        new_command <= 0'b0;

        @(posedge write_complete);
    endtask

    task read_from_peripheral (logic [7:0] addr, logic [7:0] num_regs);
        write_addr <= '0;
        write_data <= '0;
        num_regs_to_read <= num_regs;
        start_read_register_addr <= addr;
        is_write <= 1'b0;
        new_command <= 1'b1;

        wait_n_clk(2);
        new_command <= 0'b0;

        @(posedge read_complete);
    endtask


    //START OF SIMULATION   
    initial begin
        //input to channels
        DISCRIMINATOR_OUTPUT = 1'b0;

        //initializing Channel Values, CA-CE
        CA[0] <= 10'b0000000011;
        CB[0] <= 10'b0011111111;
        CC[0] <= 10'b1111000000;
        CD[0] <= 10'b0000001111;
        CE[0] <= 10'b1111111100;

        CA[1] <= 10'b1111111110;
        CB[1] <= 10'b1111111111;
        CC[1] <= 10'b1111111111;
        CD[1] <= 10'b1111111111;
        CE[1] <= 10'b1111100000;

        CA[2] <= 10'b1111111111;
        CB[2] <= 10'b1111100000;
        CC[2] <= 10'b0000011111;
        CD[2] <= 10'b1111000011;
        CE[2] <= 10'b1010101010;

        CA[3] <= 10'b1010100101;
        CB[3] <= 10'b1001010101;
        CC[3] <= 10'b0010011011;
        CD[3] <= 10'b0100001111;
        CE[3] <= 10'b0100100111;

        CA[4] <= 10'b0011101011;
        CB[4] <= 10'b0101010101;
        CC[4] <= 10'b0011010111;
        CD[4] <= 10'b1111011101;
        CE[4] <= 10'b1111101110;

        CA[5] <= 10'b0101111010;
        CB[5] <= 10'b0000010001;
        CC[5] <= 10'b0101000100;
        CD[5] <= 10'b0010011010;
        CE[5] <= 10'b0101000010;

        CA[6] <= 10'b0010010010;
        CB[6] <= 10'b1001010001;
        CC[6] <= 10'b0100110010;
        CD[6] <= 10'b0101001101;
        CE[6] <= 10'b1000101010;

        CA[7] <= 10'b1001001001;
        CB[7] <= 10'b1001010101;
        CC[7] <= 10'b0101010011;
        CD[7] <= 10'b1001010101;
        CE[7] <= 10'b0101010100;

        //input to peripheral
        pll_locked <= 8'b00000000;

        //initializing input to control
        new_command <= 1'b0;
        write_addr <= 8'b0;
        write_data <= 8'b0;
        num_regs_to_read <= '0;
        start_read_register_addr <= '0;
        is_write <= 0;

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
       write_to_peripheral(8'b0000_0001, 8'b1111_0000);

       //waiting for a reset
       wait_n_clk(10);

       //writing start to instruction
       write_to_peripheral(8'b0000_0010, 8'b0000_0011);

       //waiting for a reset
       wait_n_clk(10);

       //writing readout to instruction
       write_to_peripheral(8'b0000_0010, 8'b0000_0010);

       //waiting for a reset
       wait_n_clk(10);

       //reading out channel one
       read_from_peripheral(8'b0000_1011, 8'b0000_0010);
    end

endmodule