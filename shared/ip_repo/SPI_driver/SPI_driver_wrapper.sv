//chip SPI documentation found here: https://www.overleaf.com/9261836185kyrcvjqcqhnc#db7835

module SPI_driver_wrapper #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32,
    parameter integer N_REG = 4,

    parameter integer FIFO_DEPTH = 2048 
) (
    //core functionality
    input logic clk, //~40 MHz
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
    output logic                                 IPIF_IP2Bus_Error,

    //FIFO
    input logic fifo_rd_en,
    output logic fifo_not_empty,
    output logic fifo_full,
    output logic [7:0] fifo_dout,

    //flags
    output logic read_complete,
    output logic write_complete
);

    assign IPIF_IP2Bus_Error = 0;
   
  //add section for read data
  //add section for starting address
  //add section for number of words

   typedef struct       packed{ 
      // Register 3
      logic [21:0]      padding3;
      logic             read_complete;
      logic             write_complete;
      logic [7:0]       data_read_from_reg;
      // Register 2
      logic [15:0]      padding2;
      logic [7:0]       num_regs_to_read;
      logic [7:0]       start_read_register_addr;
      // Register 1
      logic [15:0]      padding1;
      logic [7:0]       write_register_addr;
      logic [7:0]       write_data;
      // Register 0
      logic [28:0]      padding0;
      logic             is_write; 
      logic             new_command; //Should reset after some time
      logic             rstn;
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

      params_from_IP.write_complete = write_complete;
      params_from_IP.read_complete = read_complete;
      params_from_IP.data_read_from_reg = data_read_from_reg;
   end
   
   IPIF_parameterDecode
   #(
     .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
     .N_REG(N_REG),
     .PARAM_T(param_t),
     .DEFAULTS({32'h0, 32'h0, 32'h0, 32'b1}),
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

  assign full_rstn = rstn & params_to_IP.rstn;

  logic [7:0] data_read_from_reg;
  logic fifo_wr_en;
  logic full_rstn;
  logic fifo_rst;

  SPI_driver driver (
    //common inputs
    .rstn (full_rstn),
    .clk (clk),
    .serial_in (serial_in),
    .new_command (params_to_IP.new_command),
    .is_write (is_write),

    //write inputs
    .write_register_addr (params_to_IP.write_register_addr),
    .write_data (params_to_IP.write_data),

    //read inputs
    .start_read_register_addr (start_read_register_addr),
    .num_regs_to_read (num_regs_to_read),

    //outputs
    .data_read_from_reg (data_read_from_reg),
    .serial_out (serial_out),
    .spi_clk (spi_clk),
    .write_complete (write_complete),
    .read_complete (read_complete),
    .fifo_wr_en (fifo_wr_en)
  );

  // Project Manage > Language Templates > Verilog > XPM > XPM_FIFO
  //add read block which puts all bytes into synch FIFO

  logic empty;
  assign fifo_not_empty = ~empty;

  always_ff @(posedge clk) begin
    fifo_rst <= ~full_rstn;
  end

  xpm_fifo_sync #(
      .CASCADE_HEIGHT(0),        // DECIMAL
      .DOUT_RESET_VALUE("0"),    // String
      .ECC_MODE("no_ecc"),       // String
      .FIFO_MEMORY_TYPE("auto"), // String
      .FIFO_READ_LATENCY(1),     // DECIMAL
      .FIFO_WRITE_DEPTH(FIFO_DEPTH),   // DECIMAL
      .FULL_RESET_VALUE(0),      // DECIMAL
      .PROG_EMPTY_THRESH(10),    // DECIMAL
      .PROG_FULL_THRESH(10),     // DECIMAL
      .RD_DATA_COUNT_WIDTH(1),   // DECIMAL
      .READ_DATA_WIDTH(8),      // DECIMAL
      .READ_MODE("std"),         // String
      .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES("0707"), // String
      .WAKEUP_TIME(0),           // DECIMAL
      .WRITE_DATA_WIDTH(8),     // DECIMAL
      .WR_DATA_COUNT_WIDTH($clog2(FIFO_DEPTH) + 1)    // DECIMAL
   )
   xpm_fifo_sync_inst (
      .almost_empty(),   // 1-bit output: Almost Empty : When asserted, this signal indicates that
                                     // only one more read can be performed before the FIFO goes to empty.

      .almost_full(),     // 1-bit output: Almost Full: When asserted, this signal indicates that
                                     // only one more write can be performed before the FIFO is full.

      .data_valid(),       // 1-bit output: Read Data Valid: When asserted, this signal indicates
                                     // that valid data is available on the output bus (dout).

      .dbiterr(),             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
                                     // a double-bit error and data in the FIFO core is corrupted.

      .dout(fifo_dout),                   // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
                                     // when reading the FIFO.

      .empty(empty),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the
                                     // FIFO is empty. Read requests are ignored when the FIFO is empty,
                                     // initiating a read while empty is not destructive to the FIFO.

      .full(fifo_full),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the
                                     // FIFO is full. Write requests are ignored when the FIFO is full,
                                     // initiating a write when the FIFO is full is not destructive to the
                                     // contents of the FIFO.

      .overflow(),           // 1-bit output: Overflow: This signal indicates that a write request
                                     // (wren) during the prior clock cycle was rejected, because the FIFO is
                                     // full. Overflowing the FIFO is not destructive to the contents of the
                                     // FIFO.

      .prog_empty(),       // 1-bit output: Programmable Empty: This signal is asserted when the
                                     // number of words in the FIFO is less than or equal to the programmable
                                     // empty threshold value. It is de-asserted when the number of words in
                                     // the FIFO exceeds the programmable empty threshold value.

      .prog_full(),         // 1-bit output: Programmable Full: This signal is asserted when the
                                     // number of words in the FIFO is greater than or equal to the
                                     // programmable full threshold value. It is de-asserted when the number of
                                     // words in the FIFO is less than the programmable full threshold value.

      .rd_data_count(), // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
                                     // number of words read from the FIFO.

      .rd_rst_busy(),     // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
                                     // domain is currently in a reset state.

      .sbiterr(),             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
                                     // and fixed a single-bit error.

      .underflow(),         // 1-bit output: Underflow: Indicates that the read request (rd_en) during
                                     // the previous clock cycle was rejected because the FIFO is empty. Under
                                     // flowing the FIFO is not destructive to the FIFO.

      .wr_ack(),               // 1-bit output: Write Acknowledge: This signal indicates that a write
                                     // request (wr_en) during the prior clock cycle is succeeded.

      .wr_data_count(), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
                                     // the number of words written into the FIFO.

      .wr_rst_busy(),     // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                                     // write domain is currently in a reset state.

      .din(data_read_from_reg),                     // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
                                     // writing the FIFO.

      .injectdbiterr(1'b0), // 1-bit input: Double Bit Error Injection: Injects a double bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .injectsbiterr(1'b0), // 1-bit input: Single Bit Error Injection: Injects a single bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .rd_en(fifo_rd_en),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
                                     // signal causes data (on dout) to be read from the FIFO. Must be held
                                     // active-low when rd_rst_busy is active high.

      .rst(fifo_rst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
                                     // unstable at the time of applying reset, but reset must be released only
                                     // after the clock(s) is/are stable.

      .sleep(),                 // 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
                                     // block is in power saving mode.

      .wr_clk(clk),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
                                     // free running clock.

      .wr_en(fifo_wr_en)                  // 1-bit input: Write Enable: If the FIFO is not full, asserting this
                                     // signal causes data (on din) to be written to the FIFO Must be held
                                     // active-low when rst or wr_rst_busy or rd_rst_busy is active high

   );

endmodule