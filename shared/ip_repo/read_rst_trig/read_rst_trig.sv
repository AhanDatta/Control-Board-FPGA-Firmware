module read_rst_trig #(
    parameter integer TRIGGER_COUNTER_LENGTH = 16,
    parameter integer NUM_DATA = 1280,

    parameter real CLK_PERIOD = 25.0,
    parameter real AD9228_CLK_PHASE = 28.8,

    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32,
    parameter integer N_REG = 4
)(
    input logic rstn, //FPGA reset
    input logic clk, //40 MHz, gated to chip_read_clk and with delay to AD9228_clk
    input logic trig_from_chip, //From chip, data ready to read out

    output logic chip_rst, //resets the chip, tied to IPIF interface
    output logic trig_to_chip, //triggers new data taking, tied to IPIF interface
    output logic chip_read_clk, //reads out data from capacitors
    output logic AD9228_clk, //reads out from the ADC, should be synchronus to chip_read_clk
    output logic AD9228_inverted_clk,
    output logic AD9228_read_en, //FIFO wr_en

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

    logic [TRIGGER_COUNTER_LENGTH-1:0] trigger_counter;

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
      logic             spi_readout_ready; //should be set to 1 after the readout command is sent
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
    logic prev_spi_readout_ready;
    logic spi_readout_ready;
    logic [$clog2(NUM_DATA) : 0] clock_counter;
    logic chip_read_clk_en;

    assign spi_readout_ready = params_to_IP.spi_readout_ready;
    assign chip_rst = params_to_IP.chip_rst;
    assign trig_to_chip = params_to_IP.trig_to_chip;

    //read clock gating
    BUFGMUX chip_read_clock_mux (
    .O(chip_read_clk),     // Clock output
    .I0(1'b0),            // Clock input 0 (your regular clock)
    .I1(clk),           // Clock input 1 (ground)
    .S(chip_read_clk_en && rstn)     // Select signal
);

    logic clkfb_internal;
    logic ad9228_clk_pre_buff;
    logic ad9228_clk_b_pre_buff;
    //Need to delay AD9228_clk by AD9228_CLK_PHASE
    MMCME4_BASE #(
        // Frequency synthesis parameters
        .CLKFBOUT_MULT_F(25.0),          // VCO = CLKIN × this value (2.0-64.0)
        .DIVCLK_DIVIDE(1),              // Input clock divider (1-106)
        
        // Output clock 0 (your primary delayed clock)
        .CLKOUT0_DIVIDE_F(25.0),         // Output divider (1.0-128.0)
        .CLKOUT0_DUTY_CYCLE(0.5),       // Duty cycle (0.01-0.99)
        .CLKOUT0_PHASE(AD9228_CLK_PHASE),           // Phase shift in degrees (-360.0 to 360.0)
        
        // Output clock 1 (optional second clock)
        .CLKOUT1_DIVIDE(25),             // Integer divider only (1-128)  
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT1_PHASE(AD9228_CLK_PHASE + 180), //creates inversion     
        
        // Additional outputs (2-6) available but typically unused
        .CLKOUT2_DIVIDE(1),
        .CLKOUT3_DIVIDE(1),
        .CLKOUT4_DIVIDE(1),
        .CLKOUT5_DIVIDE(1),
        .CLKOUT6_DIVIDE(1),
        
        // VCO frequency range
        .CLKFBOUT_PHASE(0.0),           // Feedback clock phase
        .REF_JITTER1(0.010),            // Input jitter specification (ns)
        .STARTUP_WAIT("FALSE"),         // Wait for MMCM lock before releasing outputs
        
        // Clock input period constraint (ns) - optional but recommended
        .CLKIN1_PERIOD(CLK_PERIOD)            // 40MHz input = 25ns period
    ) mmcm_delay_inst (
        // Clock inputs
        .CLKIN1(clk),             // Primary clock input
        .CLKFBIN(clkfb_internal),       // Feedback input (connect to CLKFBOUT)
        
        // Clock outputs  
        .CLKOUT0(ad9228_clk_pre_buff),          // phase-shifted clock
        .CLKOUT1(ad9228_clk_b_pre_buff),        // phase-shifted compliment clock
        .CLKOUT2(),                     // Unused outputs
        .CLKOUT3(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .CLKFBOUT(clkfb_internal),      // Feedback output (connect to CLKFBIN)
        
        // Control and status
        .LOCKED(),           // Lock status output
        .PWRDWN(1'b0),                  // Power down (active high)
        .RST(~rstn)                // Reset (active high)
    );

    BUFG ad9228_buffer (
        .O(AD9228_clk),
        .I(ad9228_clk_pre_buff)
    );

    BUFG ad9228_buffer_b (
        .O(AD9228_inverted_clk),
        .I(ad9228_clk_b_pre_buff)
    );

    //counts number of triggers from chip to see if we can send SPI readout
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            trigger_counter <= '0;
            prev_trig_from_chip <= 0;
        end
        else begin
            prev_trig_from_chip <= trig_from_chip;
            if (trig_from_chip && !prev_trig_from_chip) begin
                trigger_counter <= trigger_counter + 1;
            end
            else begin
                trigger_counter <= trigger_counter;
            end
        end
    end

    //Main state machine
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            chip_read_clk_en <= 0;
            AD9228_read_en <= 0;
            clock_counter <= '0;
            prev_spi_readout_ready <= 0;
            state <= IDLE;
        end
        else begin
            prev_spi_readout_ready <= spi_readout_ready;

            case (state)
                IDLE: begin
                    //start read when IPIF says spi has sent readout command
                    if (spi_readout_ready && !prev_spi_readout_ready) begin
                        chip_read_clk_en <= 1;
                        AD9228_read_en <= 0;
                        clock_counter <= 'b1;
                        state <= READ;
                    end
                    else begin
                        chip_read_clk_en <= 0;
                        AD9228_read_en <= 0;
                        clock_counter <= '0;
                        state <= IDLE;
                    end
                end

                READ: begin
                    if (clock_counter < NUM_DATA) begin
                        chip_read_clk_en <= 1;
                        AD9228_read_en <= 1;
                        clock_counter <= clock_counter + 1;
                        state <= READ;
                    end
                    else begin
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