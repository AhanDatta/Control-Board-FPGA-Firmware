`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05/18/2020 05:36:34 PM
// Design Name:
// Module Name: IPIF_parameterDecode
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module IPIF_parameterDecode #(
		parameter integer C_S_AXI_DATA_WIDTH = 32,
		parameter integer C_S_AXI_ADDR_WIDTH = 32,
		parameter integer USE_ONEHOT_READ = 1,
  		parameter integer USE_ONEHOT_WRITE = 1,
		parameter integer N_REG = 2,
		parameter type PARAM_T = logic[N_REG*C_S_AXI_DATA_WIDTH-1:0],
		parameter PARAM_T DEFAULTS = {C_S_AXI_DATA_WIDTH*N_REG*{1'b0}},
		parameter PARAM_T SELF_RESET = {C_S_AXI_DATA_WIDTH*N_REG*{1'b0}}
	)(
		input clk,

		input wire [C_S_AXI_ADDR_WIDTH-1 : 0]  IPIF_bus2ip_addr,
		input wire [C_S_AXI_DATA_WIDTH-1 : 0]  IPIF_bus2ip_data,
		input wire [N_REG-1 : 0]               IPIF_bus2ip_rdce,
		input wire                             IPIF_bus2ip_resetn,
		input wire [N_REG-1 : 0]               IPIF_bus2ip_wrce,
		input wire                             IPIF_bus2ip_wstrb,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0]  IPIF_ip2bus_data,
		output reg                             IPIF_ip2bus_rdack,
		output reg                             IPIF_ip2bus_wrack,

		output PARAM_T  parameters_out,
		input PARAM_T parameters_in
	);

	reg [C_S_AXI_DATA_WIDTH-1:0] read_reg;

	typedef union packed {
		PARAM_T param_struct;
		logic [N_REG-1:0][C_S_AXI_DATA_WIDTH-1:0] param_array;
	} param_union_t;

	param_union_t SR_union;
	assign SR_union.param_struct = SELF_RESET;

	param_union_t DEF_union;
	assign DEF_union.param_struct = DEFAULTS;

	param_union_t param_union_in;
	assign param_union_in.param_struct = parameters_in;

	param_union_t param_union_out;
	assign parameters_out = param_union_out.param_struct;

	logic [C_S_AXI_DATA_WIDTH-1:0] self_reset_cond_temp;
	logic [C_S_AXI_DATA_WIDTH-1:0] self_reset_data_temp;

	// send write acknowladge
	always @(posedge clk)
		if(!IPIF_bus2ip_resetn) IPIF_ip2bus_wrack <= 0;
		else begin
           if (USE_ONEHOT_WRITE) begin
              IPIF_ip2bus_wrack <= |IPIF_bus2ip_wrce;
           end else begin
              IPIF_ip2bus_wrack <= IPIF_bus2ip_wstrb;
           end
        end

	always @(posedge clk) begin
		if(!IPIF_bus2ip_resetn) begin
			param_union_out.param_struct <= DEFAULTS;
		end else begin
			  for(int i = 0; i < N_REG; i += 1) begin
				 self_reset_cond_temp = (SR_union.param_array[i] & (param_union_in.param_array[i] ^ DEF_union.param_array[i]));
                 
				 self_reset_data_temp = ((DEF_union.param_array[i]       &  self_reset_cond_temp) |
				                         (param_union_out.param_array[i] & ~self_reset_cond_temp));
                 
                 if (USE_ONEHOT_WRITE) begin
				    param_union_out.param_array[i] <= (IPIF_bus2ip_wrce[i] ? IPIF_bus2ip_data : self_reset_data_temp);
		         end else begin
                    param_union_out.param_array[i] <= (IPIF_bus2ip_wstrb && (i == (IPIF_bus2ip_addr>>2))) ? IPIF_bus2ip_data : self_reset_data_temp;
                 end
              end
		end
	end

	always @(posedge clk) begin
		if(!IPIF_bus2ip_resetn) begin
			IPIF_ip2bus_data <= 0;
			IPIF_ip2bus_rdack <= 0;
		end else begin
			IPIF_ip2bus_data <= read_reg;
			IPIF_ip2bus_rdack <= |IPIF_bus2ip_rdce;
		end
	end

	integer index;
	always_comb begin
		if (USE_ONEHOT_READ == 1) begin
			index = 0;
			for (int i = 0; i < N_REG; i++) begin
				if (IPIF_bus2ip_rdce[i]) begin
					index = i;
				end
			end
			//channel readback
			read_reg = param_union_in.param_array[index];
		end else begin
			read_reg = param_union_in.param_array[IPIF_bus2ip_addr>>2];
		end
	end
endmodule
