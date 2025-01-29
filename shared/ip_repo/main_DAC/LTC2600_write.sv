// Datasheet: https://www.digikey.com/en/products/detail/analog-devices-inc/LTC2600CGN-TRPBF/960897

/*
IPIF Command to Command LUT:
    0000: WRITE_TO_REG_N,
    0001: POWER_UP_REG_N,
    0010: WRITE_TO_N_POWER_ALL,
    0011: WRITE_TO_N_POWER_N,
    0100: POWER_DOWN_N,
    1111: NO_OPERATION
*/

module LTC2600_write #(
    parameter integer DATA_WIDTH = 16,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32,
    parameter integer N_REG = 4
) (
    input logic rstn,
    input logic clk, //50 MHz

    //DAC wires
    input logic sdo;
    output logic sck;
    output logic sdi;
    output logic csb;

    //outputs
    output logic write_complete;

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
);

    typedef struct       packed{ 
      // Register 3
      logic [30:0]      padding3;
      logic             ready_signal;
      // Register 2
      logic [31:0]      padding2;
      // Register 1
      logic [31:0]      padding1;
      // Register 0
      logic [7:0]      padding0;
      logic [3:0]       command;
      logic [3:0]       address;
      logic[DATA_WIDTH-1:0] data;
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

    typedef enum logic [3:0] {
        WRITE_TO_REG_N = 4'b0,
        POWER_UP_REG_N = 4'b1,
        WRITE_TO_N_POWER_ALL = 4'd2,
        WRITE_TO_N_POWER_N = 4'd3,
        POWER_DOWN_N = 4'd4,
        NO_OPERATION = 4'b1111
    } command_t;

    typedef enum logic [2:0] {
        IDLE,
        SEND_COMMAND,
        SEND_ADDRESS,
        SEND_DATA,
        COMPLETE
    } state_t;

    command_t command;
    state_t state;
    logic [3:0] address;
    logic [DATA_WIDTH-1:0] data;
    logic prev_ready_signal;
    logic [8:0] clk_counter;

    always_comb begin
        if (!rstn) begin
            sck = 1'b0;
            command = command_t'(params_to_IP.command);
            address = params_to_IP.address;
            data = params_to_IP.data;
        end
        else begin
            sck = clk; //write clock always on, since we have csb
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            prev_ready_signal <= 1'b0;
            write_complete <= 1'b0;
            sdi <= 1'b0;
            csb <= 1'b1;
            clk_counter <= 'b0;
        end
        else begin
            prev_ready_signal <= ready_signal;
            case (state) 

                IDLE: begin
                    write_complete <= 1'b0;
                    if (ready_signal & ~prev_ready_signal) begin
                        state <= SEND_COMMAND;
                        sdi <= command[3];
                        csb <= 1'b0;
                        clk_counter <= 'b1;
                    end
                    else begin
                        state <= IDLE;
                        sdi <= 1'b0;
                        csb <= 1'b1;
                        clk_counter <= 'b0;
                    end
                end

                SEND_COMMAND: begin
                    write_complete <= 1'b0;
                    csb <= 1'b0;
                    if (clk_counter == 'd4) begin
                        state <= SEND_ADDRESS;
                        sdi <= address[3];
                        clk_counter <= 'b1;
                    end
                    else begin
                        state <= SEND_COMMAND;
                        sdi <= command[3 - clk_counter];
                        clk_counter <= clk_counter + 1;
                    end
                end

                SEND_ADDRESS: begin
                    write_complete <= 1'b0;
                    csb <= 1'b0;
                    if (clk_counter == 'd4) begin
                        state <= SEND_ADDRESS;
                        sdi <= data[DATA_WIDTH - 1];
                        clk_counter <= 'b1;
                    end
                    else begin
                        state <= SEND_COMMAND;
                        sdi <= address[3 - clk_counter];
                        clk_counter <= clk_counter + 1;
                    end
                end

                SEND_DATA: begin
                    write_complete <= 1'b0;
                    if (clk_counter == 'd4) begin
                        state <= COMPLETE;
                        sdi <= 1'b0;
                        clk_counter <= 'b1;
                        csb <= 1'b1;
                    end
                    else begin
                        state <= SEND_COMMAND;
                        sdi <= data[DATA_WIDTH - 1 -clk_counter];
                        clk_counter <= clk_counter + 1;
                        csb <= 1'b0;
                    end
                end

                COMPLETE: begin
                    state <= IDLE;
                    write_complete <= 1'b1;
                    sdi <= 1'b0;
                    clk_counter <= 'b0;
                    csb <= 1'b1;
                end

            endcase
        end 
    end

endmodule