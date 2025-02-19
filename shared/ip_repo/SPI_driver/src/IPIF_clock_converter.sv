`timescale 1ns / 1ps
module repeating_handshake #(
		parameter INCLUDE_SYNCHRONIZER = 1,
		parameter integer C_S_AXI_DATA_WIDTH = 32,
		parameter integer N_REG = 2,
		parameter type PARAM_T = logic[N_REG*C_S_AXI_DATA_WIDTH-1:0]
	)(
		input  logic   src_clk,
		input  logic   dest_clk,
		input  PARAM_T src_data,
		output PARAM_T dest_data
	);


	generate
		genvar i;
		if (INCLUDE_SYNCHRONIZER) begin
			localparam WIDTH = N_REG * C_S_AXI_DATA_WIDTH;
			localparam HANDSHAKE_WIDTH = 1024;
			localparam N_HANDSHAKES = ((WIDTH - 1) / HANDSHAKE_WIDTH) + 1;
			localparam FULL_WIDTH = N_HANDSHAKES * HANDSHAKE_WIDTH;

			typedef union packed {
				PARAM_T param_struct;
				logic [N_REG*C_S_AXI_DATA_WIDTH-1:0] flat_vector;
			} param_union_t;

			param_union_t src_data_union;
			param_union_t dest_data_union;
			logic [FULL_WIDTH-1:0] src_flat;
			logic [FULL_WIDTH-1:0] dest_flat;

			assign src_data_union.param_struct = src_data;
			assign src_flat[WIDTH-1:0] = src_data_union.flat_vector;
			assign dest_data_union.flat_vector = dest_flat[WIDTH-1:0];
			assign dest_data = dest_data_union.param_struct;

			for (i = 0; i < N_HANDSHAKES; i += 1) begin
				logic send, recv;
				assign send = ~recv;
				xpm_cdc_handshake #(
					.DEST_SYNC_FF(2),
					.SRC_SYNC_FF(2),
					.INIT_SYNC_FF(1),
					.DEST_EXT_HSK(0),
					.WIDTH(HANDSHAKE_WIDTH),
					.SIM_ASSERT_CHK(1)
				) handshake (
					.src_clk(src_clk),
					.src_in(src_flat[i*HANDSHAKE_WIDTH +: HANDSHAKE_WIDTH]),
					.src_send(send),
					.src_rcv(recv),
					.dest_clk(dest_clk),
					.dest_out(dest_flat[i*HANDSHAKE_WIDTH +: HANDSHAKE_WIDTH]));
			end

		end else begin
			always @(posedge dest_clk)
				dest_data <= src_data;
		end
	endgenerate
endmodule

module IPIF_clock_converter #(
		parameter INCLUDE_SYNCHRONIZER = 1,
		parameter integer C_S_AXI_DATA_WIDTH = 32,
		parameter integer N_REG = 2,
		parameter type PARAM_T = logic[N_REG*C_S_AXI_DATA_WIDTH-1:0]
	)(
		input  logic   IP_clk,
		input  logic   bus_clk,
		input  logic   bus_clk_aresetn,
		input  PARAM_T params_from_IP,
		input  PARAM_T params_from_bus,
		output PARAM_T params_to_IP,
		output PARAM_T params_to_bus
	);

	repeating_handshake #(
		.INCLUDE_SYNCHRONIZER(INCLUDE_SYNCHRONIZER),
		.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
		.N_REG(N_REG),
		.PARAM_T(PARAM_T)
	) ip2bus (
		.src_clk(IP_clk),
		.dest_clk(bus_clk),
		.src_data(params_from_IP),
		.dest_data(params_to_bus));

	repeating_handshake #(
		.INCLUDE_SYNCHRONIZER(INCLUDE_SYNCHRONIZER),
		.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
		.N_REG(N_REG),
		.PARAM_T(PARAM_T)
	) bus2ip (
		.src_clk(bus_clk),
		.dest_clk(IP_clk),
		.src_data(params_from_bus),
		.dest_data(params_to_IP));
endmodule
