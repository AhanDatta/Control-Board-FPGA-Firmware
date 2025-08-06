# KR260 Kria Pin Constraints File
# Target: KR260 Robotics Starter Kit
# All signals are 2.5V CMOS logic
# Using PMOD connector pins for GPIO connections

# Input Signals
# serial_in_0 - PMOD1 Pin 1
set_property PACKAGE_PIN H12 [get_ports serial_in_0]
set_property IOSTANDARD LVCMOS25 [get_ports serial_in_0]

# trig_from_chip_0 - PMOD1 Pin 2  
set_property PACKAGE_PIN E10 [get_ports trig_from_chip_0]
set_property IOSTANDARD LVCMOS25 [get_ports trig_from_chip_0]

# Output Signals
# spi_clk_0 - PMOD1 Pin 3
set_property PACKAGE_PIN D10 [get_ports spi_clk_0]
set_property IOSTANDARD LVCMOS25 [get_ports spi_clk_0]

# serial_out_0 - PMOD1 Pin 4
set_property PACKAGE_PIN C11 [get_ports serial_out_0]
set_property IOSTANDARD LVCMOS25 [get_ports serial_out_0]

# chip_rst_0 - PMOD1 Pin 7
set_property PACKAGE_PIN B10 [get_ports chip_rst_0]
set_property IOSTANDARD LVCMOS25 [get_ports chip_rst_0]

# trig_to_chip_0 - PMOD1 Pin 8
set_property PACKAGE_PIN E12 [get_ports trig_to_chip_0]
set_property IOSTANDARD LVCMOS25 [get_ports trig_to_chip_0]

# chip_read_clk_0 - PMOD1 Pin 9
set_property PACKAGE_PIN D11 [get_ports chip_read_clk_0]
set_property IOSTANDARD LVCMOS25 [get_ports chip_read_clk_0]