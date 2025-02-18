//adc clk (diff -> single ended), csb (single ended) needs to be handled here

module AD9228_read #(
    parameter NUM_CHANNELS = 8,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32,
    parameter integer N_REG = 4,
    parameter integer DATA_WIDTH = 12
) (
    //common inputs
    input logic clk, //65 Mhz
    input logic rstn,

    //AD9228 inputs (indexed by channel)
    input logic [NUM_CHANNELS-1 : 0] din_p,
    input logic [NUM_CHANNELS-1 : 0] din_n,
    input logic [NUM_CHANNELS-1 : 0] fco_p,
    input logic [NUM_CHANNELS-1 : 0] fco_n,
    input logic [NUM_CHANNELS-1 : 0] dco_p,
    input logic [NUM_CHANNELS-1 : 0] dco_n,

    //Common/SPI adc connections
    output logic clk_p,
    output logic clk_n,
    output logic csb,

    //FIFO connections (indexed by channel)
    input logic [NUM_CHANNELS-1 : 0] fifo_rd_en,
    input logic [NUM_CHANNELS-1 : 0] fifo_rd_clk,
    output logic [NUM_CHANNELS-1 : 0] fifo_not_empty,
    output logic [NUM_CHANNELS-1 : 0] fifo_full,
    output logic [NUM_CHANNELS-1 : 0][DATA_WIDTH-1:0] fifo_dout,

    //IPIF interface
    //configuration parameter interface 
    input logic                                  IPIF_Bus2IP_resetn,
    input logic [(C_S_AXI_ADDR_WIDTH-1) : 0]     IPIF_Bus2IP_Addr, //unused
    input logic                                  IPIF_Bus2IP_RNW, //unused
    input logic [((C_S_AXI_DATA_WIDTH/8)-1) : 0] IPIF_Bus2IP_BE, //unused
    input logic [0 : 0]                          IPIF_Bus2IP_CS, //unused
    input logic [N_REG-1 : 0]                    IPIF_Bus2IP_RdCE, 
    input logic [N_REG-1 : 0]                    IPIF_Bus2IP_WrCE,
    input logic [(C_S_AXI_DATA_WIDTH-1) : 0]     IPIF_Bus2IP_Data,
    output logic [(C_S_AXI_DATA_WIDTH-1) : 0]    IPIF_IP2Bus_Data,
    output logic                                 IPIF_IP2Bus_WrAck,
    output logic                                 IPIF_IP2Bus_RdAck,
    output logic                                 IPIF_IP2Bus_Error
);

    typedef struct       packed{ 
      // Register 3
      logic [30:0]      padding3;
      logic             keep_reading;
      // Register 2
      logic [31:0]      padding2;
      // Register 1
      logic [31:0]      padding1;
      // Register 0
      logic [31:0]      padding0;
   } param_t;

    param_t params_from_IP; //use this
    param_t params_from_bus;
    param_t params_to_IP; //use this
    param_t params_to_bus;

    always_comb begin
      params_from_IP = params_to_IP;
      //More efficient to explicitely zero padding 
      params_from_IP.padding0   = '0;
      params_from_IP.padding1   = '0;
      params_from_IP.padding2   = '0;
      params_from_IP.padding3   = '0;
   end

    IPIF_parameterDecode
   #(
     .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
     .N_REG(N_REG),
     .PARAM_T(param_t),
     .DEFAULTS({32'h0, 32'd1, 32'h0, 32'b0}),
     .SELF_RESET(128'b1)
     ) parameterDecoder 
   (
    .clk(IPIF_clk),
    
    .IPIF_bus2ip_data(IPIF_Bus2IP_Data),  
    .IPIF_bus2ip_rdce(IPIF_Bus2IP_RdCE),
    .IPIF_bus2ip_resetn(IPIF_Bus2IP_resetn),
    .IPIF_bus2ip_wrce(IPIF_Bus2IP_WrCE),
    .IPIF_ip2bus_data(IPIF_IP2Bus_Data),
    .IPIF_ip2bus_rdack(IPIF_IP2Bus_RdAck),
    .IPIF_ip2bus_wrack(IPIF_IP2Bus_WrAck),
    
    .parameters_out(params_from_bus),
    .parameters_in(params_to_bus)
    );

   IPIF_clock_converter 
    #(
     .INCLUDE_SYNCHRONIZER(1),
     .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
     .N_REG(N_REG),
     .PARAM_T(param_t)
     ) IPIF_clock_conv 
    (
    .IP_clk(clk),
    .bus_clk(IPIF_clk),
    .params_from_IP(params_from_IP),
    .params_from_bus(params_from_bus),
    .params_to_IP(params_to_IP),
    .params_to_bus(params_to_bus)
    );

    logic sample_clk;

    //generating each of the channels
    genvar i;
    generate
        for (i=0; i < NUM_CHANNELS; i = i+1) begin : channel_instantiations
            AD9228_single_ch_read  AD9228_single_ch_read_inst (
                .clk (clk),
                .rstn (rstn),

                .din_p (din_p[i]),
                .din_n (din_n[i]),
                .fco_p (fco_p[i]),
                .fco_n (fco_n[i]),
                .dco_p (dco_p[i]),
                .dco_n (dco_n[i]),

                .fifo_rd_en (fifo_rd_en[i]),
                .fifo_rd_clk (fifo_rd_clk[i]),
                .fifo_not_empty (fifo_not_empty[i]),
                .fifo_full (fifo_full[i]),
                .fifo_dout (fifo_dout[i])
            );
        end
    endgenerate

    //gating the sampling clock on the IPIF command
    always_comb begin
        if (!rstn) begin
            sample_clk = 1'b0;
        end
        else begin
            if (params_to_IP.keep_reading) begin
                sample_clk = clk;
            end
            else begin 
                sample_clk = 1'b0;
            end
        end
    end

    single_ended_to_diff adc_clk_conv (
        .single_in (sample_clk),
        .diff_p (clk_p),
        .diff_n (clk_n)
    );

    //placeholder for real SPI block
    assign csb = 1'b1;
endmodule