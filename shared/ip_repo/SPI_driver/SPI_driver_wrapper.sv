//chip SPI documentation found here: https://www.overleaf.com/9261836185kyrcvjqcqhnc#db7835

module SPI_driver_wrapper #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32,
    parameter integer N_REG = 4
) (
    input logic clk,
    input logic rstn,
    input logic serial_in,
    output logic spi_clk,
    output logic serial_out,

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

    assign IPIF_IP2Bus_Error = 0;
   
  //add section for read data
  //add section for starting address
  //add section for number of words

   typedef struct       packed{ 
      // Register 3
      logic             new_command; //Should reset after some time
      logic             rstn;
      logic [30:0]      padding3;
      // Register 2
      logic [23:0]      padding2;
      logic [7:0]       register_addr;
      // Register 1
      logic [23:0]      padding1;
      logic [7:0]       write_data;
      // Register 0
      logic [22:0]      padding0;
      logic             transaction_complete;
      logic [7:0]       data_read_from_reg;
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

      params_from_IP.transaction_complete = transaction_complete;
      params_from_IP.data_read_from_reg = data_read_from_reg;
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

  assign logic full_rstn = rstn & params_to_IP.rstn;

  logic [7:0] data_read_from_reg;
  logic transaction_complete;

  SPI_driver driver_inst (
    .rstn (full_rstn),
    .clk (clk),
    .serial_in (serial_in),
    .new_command (params_to_IP.new_command),
    .register_addr (params_to_IP.register_addr),
    .write_data (params_to_IP.write_data),
    .data_read_from_reg (data_read_from_reg),
    .serial_out (serial_out),
    .spi_clk (spi_clk),
    .transaction_complete (transaction_complete)
  );

  // Project Manage > Language Templates > Verilog > XPM > XPM_FIFO
  //add read block which puts all bytes into synch FIFO

endmodule