# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  ipgui::add_page $IPINST -name "Page 0"

  set DIN_INVERTED [ipgui::add_param $IPINST -name "DIN_INVERTED"]
  set_property tooltip {Controls if the data in differential signals are inverted} ${DIN_INVERTED}
  set DCO_INVERTED [ipgui::add_param $IPINST -name "DCO_INVERTED"]
  set_property tooltip {Controls if the data clock differential signals are inverted} ${DCO_INVERTED}
  set FCO_INVERTED [ipgui::add_param $IPINST -name "FCO_INVERTED"]
  set_property tooltip {Controls if the sampling clock differential signals are inverted} ${FCO_INVERTED}
  set SAMPLING_CLK_INVERTED [ipgui::add_param $IPINST -name "SAMPLING_CLK_INVERTED"]
  set_property tooltip {Controls if the sampling clock differential signals are inverted} ${SAMPLING_CLK_INVERTED}

}

proc update_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to update DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to validate DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.DCO_INVERTED { PARAM_VALUE.DCO_INVERTED } {
	# Procedure called to update DCO_INVERTED when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DCO_INVERTED { PARAM_VALUE.DCO_INVERTED } {
	# Procedure called to validate DCO_INVERTED
	return true
}

proc update_PARAM_VALUE.DIN_INVERTED { PARAM_VALUE.DIN_INVERTED } {
	# Procedure called to update DIN_INVERTED when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DIN_INVERTED { PARAM_VALUE.DIN_INVERTED } {
	# Procedure called to validate DIN_INVERTED
	return true
}

proc update_PARAM_VALUE.FCO_INVERTED { PARAM_VALUE.FCO_INVERTED } {
	# Procedure called to update FCO_INVERTED when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FCO_INVERTED { PARAM_VALUE.FCO_INVERTED } {
	# Procedure called to validate FCO_INVERTED
	return true
}

proc update_PARAM_VALUE.NUM_CHANNELS { PARAM_VALUE.NUM_CHANNELS } {
	# Procedure called to update NUM_CHANNELS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.NUM_CHANNELS { PARAM_VALUE.NUM_CHANNELS } {
	# Procedure called to validate NUM_CHANNELS
	return true
}

proc update_PARAM_VALUE.SAMPLING_CLK_INVERTED { PARAM_VALUE.SAMPLING_CLK_INVERTED } {
	# Procedure called to update SAMPLING_CLK_INVERTED when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SAMPLING_CLK_INVERTED { PARAM_VALUE.SAMPLING_CLK_INVERTED } {
	# Procedure called to validate SAMPLING_CLK_INVERTED
	return true
}


proc update_MODELPARAM_VALUE.NUM_CHANNELS { MODELPARAM_VALUE.NUM_CHANNELS PARAM_VALUE.NUM_CHANNELS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.NUM_CHANNELS}] ${MODELPARAM_VALUE.NUM_CHANNELS}
}

proc update_MODELPARAM_VALUE.DATA_WIDTH { MODELPARAM_VALUE.DATA_WIDTH PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_WIDTH}] ${MODELPARAM_VALUE.DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.DIN_INVERTED { MODELPARAM_VALUE.DIN_INVERTED PARAM_VALUE.DIN_INVERTED } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DIN_INVERTED}] ${MODELPARAM_VALUE.DIN_INVERTED}
}

proc update_MODELPARAM_VALUE.DCO_INVERTED { MODELPARAM_VALUE.DCO_INVERTED PARAM_VALUE.DCO_INVERTED } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DCO_INVERTED}] ${MODELPARAM_VALUE.DCO_INVERTED}
}

proc update_MODELPARAM_VALUE.FCO_INVERTED { MODELPARAM_VALUE.FCO_INVERTED PARAM_VALUE.FCO_INVERTED } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FCO_INVERTED}] ${MODELPARAM_VALUE.FCO_INVERTED}
}

proc update_MODELPARAM_VALUE.SAMPLING_CLK_INVERTED { MODELPARAM_VALUE.SAMPLING_CLK_INVERTED PARAM_VALUE.SAMPLING_CLK_INVERTED } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SAMPLING_CLK_INVERTED}] ${MODELPARAM_VALUE.SAMPLING_CLK_INVERTED}
}

