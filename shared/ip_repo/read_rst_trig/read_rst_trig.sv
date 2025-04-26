module read_rst_trig #(
    parameter integer TRIGGER_COUNTER_LENGTH = 16,
    parameter integer NUM_DATA = 1280,

    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32,
    parameter integer N_REG = 4
)(
    input logic rstn, //FPGA reset
    input logic clk, //40 MHz, gated to chip_read_clk and AD9228_clk
    input logic trig_from_chip, //From chip
    input logic delay_clk, //400 MHz

    output logic chip_rst,
    output logic trig_to_chip,
    output logic chip_read_clk,
    output logic AD9228_clk,
    output logic AD9228_read_en,

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
   
    typedef struct       packed{
      // Register 3
      logic [31-TRIGGER_COUNTER_LENGTH:0]      padding3;
      logic [TRIGGER_COUNTER_LENGTH-1:0]      trigger_counter;
      // Register 2
      logic [31:0]      padding2;
      // Register 1
      logic [31:0]      padding1;
      // Register 0
      logic [28:0]      padding0;
      logic             software_trig;
      logic             trig_to_chip;
      logic             chip_rst;
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
      params_from_IP.trigger_counter = trigger_counter;
   end
   
   IPIF_parameterDecode
   #(
     .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
     .N_REG(N_REG),
     .PARAM_T(param_t),
     .DEFAULTS({32'h0, 32'h0, 32'h0, 32'b0}),
     .SELF_RESET(128'b111)
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

    typedef enum logic {
        IDLE,
        READ
    } state_t;

    state_t state;
    logic prev_trig_from_chip;
    logic prev_software_trig;
    logic [$clog2(NUM_DATA) : 0] clock_counter;
    logic [TRIGGER_COUNTER_LENGTH-1:0] trigger_counter;
    logic chip_read_clk_en;

    assign chip_rst = params_to_IP.chip_rst;
    assign trig_to_chip = params_to_IP.trig_to_chip;

    //Clock gating
    always_comb begin
        if (!rstn) begin
            chip_read_clk = 0;
        end
        else if (chip_read_clk_en) begin
            chip_read_clk = clk;
        end
        else begin
            chip_read_clk = 0;
        end
    end

    assign AD9228_clk = clk; 
    ODELAYE3 #(
        .CASCADE("NONE"),               // Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
        .DELAY_FORMAT("TIME"),          // (COUNT, TIME)
        .DELAY_TYPE("FIXED"),           // Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
        .DELAY_VALUE(5),                // Output delay tap setting | LESS THAN 7 TO SATISFY TIMING (FCO high and data latched within one clock cycle of clk)
        .IS_CLK_INVERTED(1'b0),         // Optional inversion for CLK
        .IS_RST_INVERTED(1'b1),         // Optional inversion for RST
        .REFCLK_FREQUENCY(400.0),       // IDELAYCTRL clock input frequency in MHz (200.0-800.0).
        .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE,
                                        // ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
        .UPDATE_MODE("ASYNC")           // Determines when updates to the delay will take effect (ASYNC, MANUAL,
                                        // SYNC)
    )
    ODELAYE3_inst (
        .CASC_OUT(),       // 1-bit output: Cascade delay output to IDELAY input cascade
        .CNTVALUEOUT(), // 9-bit output: Counter value output
        .DATAOUT(AD9228_clk),         // 1-bit output: Delayed data from ODATAIN input port
        .CASC_IN(),         // 1-bit input: Cascade delay input from slave IDELAY CASCADE_OUT
        .CASC_RETURN(), // 1-bit input: Cascade delay returning from slave IDELAY DATAOUT
        .CE(),                   // 1-bit input: Active-High enable increment/decrement input
        .CLK(delay_clk),                 // 1-bit input: Clock input
        .CNTVALUEIN(),   // 9-bit input: Counter value input
        .EN_VTC(),           // 1-bit input: Keep delay constant over VT
        .INC(),                 // 1-bit input: Increment/Decrement tap delay input
        .LOAD(),               // 1-bit input: Load DELAY_VALUE input
        .ODATAIN(clk),         // 1-bit input: Data input
        .RST(rstn)                  // 1-bit input: Asynchronous Reset to the DELAY_VALUE
    );

    //Main state machine
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            trigger_counter <= '0;
            chip_read_clk_en <= 0;
            AD9228_read_en <= 0;
            clock_counter <= '0;
            prev_trig_from_chip <= '0;
            prev_software_trig <= 0;
            state <= IDLE;
        end
        else begin
            prev_trig_from_chip <= trig_from_chip;
            prev_software_trig <= params_to_IP.software_trig;

            case (state)
                IDLE: begin
                    //start read on trigger
                    if ((trig_from_chip && !prev_trig_from_chip) || (params_to_IP.software_trig && !prev_software_trig)) begin
                        trigger_counter <= trigger_counter + 1;
                        chip_read_clk_en <= 1;
                        AD9228_read_en <= 0;
                        clock_counter <= 'b1;
                        state <= READ;
                    end
                    else begin
                        trigger_counter <= trigger_counter;
                        chip_read_clk_en <= 0;
                        AD9228_read_en <= 0;
                        clock_counter <= '0;
                        state <= IDLE;
                    end
                end

                READ: begin
                    if (clock_counter < NUM_DATA) begin
                        trigger_counter <= trigger_counter;
                        chip_read_clk_en <= 1;
                        AD9228_read_en <= 1;
                        clock_counter <= clock_counter + 1;
                        state <= READ;
                    end
                    else begin
                        trigger_counter <= trigger_counter;
                        chip_read_clk_en <= 0;
                        AD9228_read_en <= 1;
                        clock_counter <= '0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule