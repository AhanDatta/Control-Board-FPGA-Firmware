module pll_external #(
    parameter ADC_WIDTH = 16,
    parameter DAC_WIDTH = 16,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32,
    parameter integer N_REG = 4
) (
    input logic clk, //for both adc and dac drivers
    input logic adc_resetn, //needs to be held
    input logic input_from_adc,
    output logic adc_sck,
    output logic adc_cnv,
    output logic adc_resetn_confirm,
    input logic dac_resetn, 
    output logic dac_sclk,
    output logic dac_write,
    output logic dac_syncn,

    input wire                                   IPIF_clk,
                                                
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

    logic [ADC_WIDTH-1:0] amplified_data;

    assign IPIF_IP2Bus_Error = 0;
   
   typedef struct       packed{
      // Register 3
      logic [31:0]      padding3;
      // Register 2
      logic [31:0]      padding2;
      // Register 1
      logic [15:0]      padding1;
      logic [15:0]      gain;
      // Register 0
      logic [29:0]      padding0;
      logic             dac_resetn;
      logic             adc_resetn;
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
     .SELF_RESET(128'b11)
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

    AD4008_read adc_in (
        .clk (clk),
        .aresetn (adc_resetn & params_to_IP.adc_resetn),
        .data_in (input_from_adc),
        .GAIN (gain),
        .cnv (adc_cnv),
        .sck (adc_sck),
        .sresetn (adc_resetn_confirm),
        .new_data_flag (),
        .amplified_data (amplified_data)
    );

    DAC8411_write dac_out (
        .clk (clk),
        .aresetn (dac_resetn & params_to_IP.dac_resetn),
        .data_in (amplified_data),
        .sclk (dac_sclk),
        .serial_data_out (dac_write),
        .syncn (dac_syncn)
    );

endmodule