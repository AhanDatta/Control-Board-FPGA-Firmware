###############################################################
# Kria K26 SOM XDC File
# For PSEC5 Control Board v1
# Generated on: May 13, 2025
###############################################################

###############################################################
# Bank Voltages
###############################################################
# HDA: 2.5V 
# HBD: 2.5V
# HDC: 1.8V
# HPA: 1.8V
# HPB: 1.8V
# HPC: 1.8V

###############################################################
# AD9228 Pins - Bank HPA
###############################################################
# AD9228_1 Data Pins
set_property -dict {PACKAGE_PIN A2 IOSTANDARD LVDS} [get_ports {AD9228_din_p_1[0]}]
set_property -dict {PACKAGE_PIN A1 IOSTANDARD LVDS} [get_ports {AD9228_din_n_1[0]}]
set_property -dict {PACKAGE_PIN C3 IOSTANDARD LVDS} [get_ports {AD9228_din_p_1[1]}]
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVDS} [get_ports {AD9228_din_n_1[1]}]
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVDS} [get_ports {AD9228_din_p_1[2]}]
set_property -dict {PACKAGE_PIN G6 IOSTANDARD LVDS} [get_ports {AD9228_din_n_1[2]}]
set_property -dict {PACKAGE_PIN G8 IOSTANDARD LVDS} [get_ports {AD9228_din_p_1[3]}]
set_property -dict {PACKAGE_PIN F7 IOSTANDARD LVDS} [get_ports {AD9228_din_n_1[3]}]

# AD9228_1 Sampling Clock and Frame Clock
set_property -dict {PACKAGE_PIN A4 IOSTANDARD LVDS} [get_ports AD9228_clk_n_1]
set_property -dict {PACKAGE_PIN B4 IOSTANDARD LVDS} [get_ports AD9228_clk_p_1]
set_property -dict {PACKAGE_PIN A3 IOSTANDARD LVDS} [get_ports AD9228_fco_n_1]
set_property -dict {PACKAGE_PIN B3 IOSTANDARD LVDS} [get_ports AD9228_fco_p_1]
set_property -dict {PACKAGE_PIN B1 IOSTANDARD LVDS} [get_ports AD9228_dco_n_1]
set_property -dict {PACKAGE_PIN C1 IOSTANDARD LVDS} [get_ports AD9228_dco_p_1]

# AD9228_0 Data Pins
set_property -dict {PACKAGE_PIN F8 IOSTANDARD LVDS} [get_ports {AD9228_din_p_0[0]}]
set_property -dict {PACKAGE_PIN E8 IOSTANDARD LVDS} [get_ports {AD9228_din_n_0[0]}]
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVDS} [get_ports {AD9228_din_p_0[1]}]
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVDS} [get_ports {AD9228_din_n_0[1]}]
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVDS} [get_ports {AD9228_din_n_0[2]}]
set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVDS} [get_ports {AD9228_din_p_0[3]}]
set_property -dict {PACKAGE_PIN F2 IOSTANDARD LVDS} [get_ports {AD9228_din_n_0[3]}]

# AD9228_0 Sampling Clock and Frame Clock
set_property -dict {PACKAGE_PIN F1 IOSTANDARD LVDS} [get_ports AD9228_clk_p_0]
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVDS} [get_ports AD9228_clk_n_0]
set_property -dict {PACKAGE_PIN F3 IOSTANDARD LVDS} [get_ports AD9228_fco_p_0]
set_property -dict {PACKAGE_PIN G3 IOSTANDARD LVDS} [get_ports AD9228_fco_n_0]
set_property -dict {PACKAGE_PIN D6 IOSTANDARD LVDS} [get_ports AD9228_dco_p_0]
set_property -dict {PACKAGE_PIN D7 IOSTANDARD LVDS} [get_ports AD9228_dco_n_0]

###############################################################
# SPI Interfaces - Bank HPA
###############################################################
set_property -dict {PACKAGE_PIN D5 IOSTANDARD LVCMOS18} [get_ports sck_t_1]
set_property -dict {PACKAGE_PIN E5 IOSTANDARD LVCMOS18} [get_ports io0_t_1]
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS18} [get_ports sck_t_0]
set_property -dict {PACKAGE_PIN E4 IOSTANDARD LVCMOS18} [get_ports io0_t_0]

###############################################################
# Chip Control - Bank HDA
###############################################################
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS25} [get_ports chip_read_clk_0]
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS25} [get_ports spi_serial_in_0]
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS25} [get_ports spi_serial_out_0]
set_property -dict {PACKAGE_PIN E10 IOSTANDARD LVCMOS25} [get_ports trig_to_chip_0]
set_property -dict {PACKAGE_PIN F10 IOSTANDARD LVCMOS25} [get_ports chip_rst_0]
set_property -dict {PACKAGE_PIN J11 IOSTANDARD LVCMOS25} [get_ports trig_from_chip_0]
set_property -dict {PACKAGE_PIN F12 IOSTANDARD LVCMOS25} [get_ports spi_clk_0]

###############################################################
# LTC2600 DAC Interfaces - Bank HDA
###############################################################
# LTC2600_0
set_property -dict {PACKAGE_PIN J10 IOSTANDARD LVCMOS25} [get_ports LTC2600_csb_0]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS25} [get_ports LTC2600_sck_0]
set_property -dict {PACKAGE_PIN J12 IOSTANDARD LVCMOS25} [get_ports LTC2600_sdi_0]
set_property -dict {PACKAGE_PIN F11 IOSTANDARD LVCMOS25} [get_ports {LTC2600_clrb_0[1]}]

# LTC2600_1
set_property -dict {PACKAGE_PIN H11 IOSTANDARD LVCMOS25} [get_ports LTC2600_csb_1]
set_property -dict {PACKAGE_PIN H12 IOSTANDARD LVCMOS25} [get_ports LTC2600_sck_1]
set_property -dict {PACKAGE_PIN G10 IOSTANDARD LVCMOS25} [get_ports LTC2600_sdi_1]

# LTC2600_2
set_property -dict {PACKAGE_PIN AF11 IOSTANDARD LVCMOS25} [get_ports LTC2600_csb_2]
set_property -dict {PACKAGE_PIN AF12 IOSTANDARD LVCMOS25} [get_ports LTC2600_sdi_2]
set_property -dict {PACKAGE_PIN AH10 IOSTANDARD LVCMOS25} [get_ports LTC2600_sck_2]
set_property -dict {PACKAGE_PIN AG10 IOSTANDARD LVCMOS25} [get_ports {LTC2600_clrb_0[1]}]

###############################################################
# DAC8411 Interface - Bank HDB/HDC
###############################################################
set_property -dict {PACKAGE_PIN AD12 IOSTANDARD LVCMOS25} [get_ports DAC8411_syncn_0]
set_property -dict {PACKAGE_PIN AE10 IOSTANDARD LVCMOS25} [get_ports DAC8411_sclk_0]
set_property -dict {PACKAGE_PIN AE14 IOSTANDARD LVCMOS18} [get_ports DAC8411_din_0]
set_property -dict {PACKAGE_PIN W10 IOSTANDARD LVCMOS25} [get_ports DAC8411_din_0]

###############################################################
# AD4008 ADC Interface - Bank HDB/HDC 
###############################################################
set_property -dict {PACKAGE_PIN Y10 IOSTANDARD LVCMOS25} [get_ports AD4008_cnv_0]
set_property -dict {PACKAGE_PIN AD14 IOSTANDARD LVCMOS18} [get_ports AD4008_sdo_0]
set_property -dict {PACKAGE_PIN AD15 IOSTANDARD LVCMOS18} [get_ports AD4008_sck_0]
set_property -dict {PACKAGE_PIN AE15 IOSTANDARD LVCMOS18} [get_ports AD4008_cnv_0]

# Errors:
# set_property expects one object: 9, 10, 11, 12, 13, 14, 57, 58, 59, 60, 99, 104
# wrong side of differential pair: 24, 25, 40, 41, 42, 43, 44, 47, 48, 49, 50, 51, 52
# pin assigned to more than one port: 80, 91