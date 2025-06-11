//Must be greater than 1ps/ps
`timescale 1ns/1ps

module main_design_testbench ();

    logic AD4008_cnv_0;
    logic AD4008_sck_0;
    logic AD4008_sdo_0;
    logic AD9228_clk_n_0;
    logic AD9228_clk_n_1;
    logic AD9228_clk_p_0;
    logic AD9228_clk_p_1;
    logic AD9228_dco_n_0;
    logic AD9228_dco_n_1;
    logic AD9228_dco_p_0;
    logic AD9228_dco_p_1;
    logic [3:0]AD9228_din_n_0;
    logic [3:0]AD9228_din_n_1;
    logic [3:0]AD9228_din_p_0;
    logic [3:0]AD9228_din_p_1;
    logic AD9228_fco_n_0;
    logic AD9228_fco_n_1;
    logic AD9228_fco_p_0;
    logic AD9228_fco_p_1;
    logic DAC8411_din_0;
    logic DAC8411_sclk_0;
    logic DAC8411_syncn_0;
    logic [1:0]LTC2600_clrb_0;
    logic LTC2600_csb_0;
    logic LTC2600_csb_1;
    logic LTC2600_csb_2;
    logic LTC2600_sck_0;
    logic LTC2600_sck_1;
    logic LTC2600_sck_2;
    logic LTC2600_sdi_0;
    logic LTC2600_sdi_1;
    logic LTC2600_sdi_2;
    logic chip_read_clk_0;
    logic chip_rst_0;
    logic io0_t_0;
    logic io0_t_1;
    logic sck_t_0;
    logic sck_t_1;
    logic spi_clk_0;
    logic spi_serial_in_0;
    logic spi_serial_out_0;
    logic trig_from_chip_0;
    logic trig_to_chip_0;

    cb_block_design_2_wrapper DUT
       (.AD4008_cnv_0(AD4008_cnv_0),
        .AD4008_sck_0(AD4008_sck_0),
        .AD4008_sdo_0(AD4008_sdo_0),
        .AD9228_clk_n_0(AD9228_clk_n_0),
        .AD9228_clk_n_1(AD9228_clk_n_1),
        .AD9228_clk_p_0(AD9228_clk_p_0),
        .AD9228_clk_p_1(AD9228_clk_p_1),
        .AD9228_dco_n_0(AD9228_dco_n_0),
        .AD9228_dco_n_1(AD9228_dco_n_1),
        .AD9228_dco_p_0(AD9228_dco_p_0),
        .AD9228_dco_p_1(AD9228_dco_p_1),
        .AD9228_din_n_0(AD9228_din_n_0),
        .AD9228_din_n_1(AD9228_din_n_1),
        .AD9228_din_p_0(AD9228_din_p_0),
        .AD9228_din_p_1(AD9228_din_p_1),
        .AD9228_fco_n_0(AD9228_fco_n_0),
        .AD9228_fco_n_1(AD9228_fco_n_1),
        .AD9228_fco_p_0(AD9228_fco_p_0),
        .AD9228_fco_p_1(AD9228_fco_p_1),
        .DAC8411_din_0(DAC8411_din_0),
        .DAC8411_sclk_0(DAC8411_sclk_0),
        .DAC8411_syncn_0(DAC8411_syncn_0),
        .LTC2600_clrb_0(LTC2600_clrb_0),
        .LTC2600_csb_0(LTC2600_csb_0),
        .LTC2600_csb_1(LTC2600_csb_1),
        .LTC2600_csb_2(LTC2600_csb_2),
        .LTC2600_sck_0(LTC2600_sck_0),
        .LTC2600_sck_1(LTC2600_sck_1),
        .LTC2600_sck_2(LTC2600_sck_2),
        .LTC2600_sdi_0(LTC2600_sdi_0),
        .LTC2600_sdi_1(LTC2600_sdi_1),
        .LTC2600_sdi_2(LTC2600_sdi_2),
        .chip_read_clk_0(chip_read_clk_0),
        .chip_rst_0(chip_rst_0),
        .io0_t_0(io0_t_0),
        .io0_t_1(io0_t_1),
        .sck_t_0(sck_t_0),
        .sck_t_1(sck_t_1),
        .spi_clk_0(spi_clk_0),
        .spi_serial_in_0(spi_serial_in_0),
        .spi_serial_out_0(spi_serial_out_0),
        .trig_from_chip_0(trig_from_chip_0),
        .trig_to_chip_0(trig_to_chip_0));

        logic resp;
        logic tb_aclk;
        logic tb_arstn;

        //driving differential signals from single ended for convenience 
        logic AD9228_clk_0;
        logic AD9228_clk_1;
        logic AD9228_dco_0;
        logic AD9228_dco_1;
        logic [3:0] AD9228_din_0;
        logic [3:0] AD9228_din_1;
        logic AD9228_fco_0;
        logic AD9228_fco_1;

        assign AD9228_clk_n_0 = !AD9228_clk_0;
        assign AD9228_clk_n_1 = !AD9228_clk_1;
        assign AD9228_clk_p_0 = AD9228_clk_0;
        assign AD9228_clk_p_1 = AD9228_clk_1;
        assign AD9228_dco_n_0 = !AD9228_dco_0;
        assign AD9228_dco_n_1 = !AD9228_dco_1;
        assign AD9228_dco_p_0 = AD9228_dco_0;
        assign AD9228_dco_p_1 = AD9228_dco_1;
        assign AD9228_din_n_0 = ~AD9228_din_0;
        assign AD9228_din_n_1 = ~AD9228_din_1;
        assign AD9228_din_p_0 = AD9228_din_0;
        assign AD9228_din_p_1 = AD9228_din_1;
        assign AD9228_fco_n_0 = !AD9228_fco_0;
        assign AD9228_fco_n_1 = !AD9228_fco_1;
        assign AD9228_fco_p_0 = AD9228_fco_0;
        assign AD9228_fco_p_1 = AD9228_fco_1;

endmodule