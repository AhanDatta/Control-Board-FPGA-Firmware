module AD9228_core_SERDES #(
    parameter logic DIN_INVERTED = 0,
    parameter integer DATA_WIDTH = 12
) (
    input logic rstn, //should be sync to dco_div4
    input logic refclk_200M,

    //adc inputs
    input logic din,
    input logic fco,  //fco = dco/6
    input logic dco,  //DDR clock for data
    input logic dco_div4, //dco divided by four for SERDES

    output logic [DATA_WIDTH-1:0] des_data,
    output logic des_data_valid
);

    logic idelay_rdy;
    logic din_delayed;
    logic [7:0] ddr_data;  //8 bits collected over 4 DDR cycles by SERDES
    logic [7:0] ddr_data_processed; //accounts for DIN_INVERTED

    //handles DIN_INVERTED
    generate 
        if (DIN_INVERTED) begin : din_gen_inv
            assign ddr_data_processed = ~ddr_data;
        end 
        else begin : din_gen_normal
            assign ddr_data_processed = ddr_data;
        end
    endgenerate

    // //IDELAYCTRL - required for IDELAYE3 operation
    // IDELAYCTRL #(
    //     .SIM_DEVICE("ULTRASCALE_PLUS")
    // ) idelayctrl_inst (
    //     .RDY(idelay_rdy),       //Ready output - indicates IDELAYCTRL is ready
    //     .REFCLK(refclk_200M), //200MHz reference clock input
    //     .RST(~rstn)             
    // );

    // //timing alignment
    // IDELAYE3 #(
    //     .CASCADE("NONE"),
    //     .DELAY_FORMAT("TIME"),
    //     .DELAY_TYPE("FIXED"),
    //     .DELAY_VALUE(0),
    //     .IS_CLK_INVERTED(1'b0),
    //     .IS_RST_INVERTED(1'b0),
    //     .REFCLK_FREQUENCY(200.0),
    //     .SIM_DEVICE("ULTRASCALE_PLUS"),
    //     .UPDATE_MODE("ASYNC")
    // ) din_delay_inst (
    //     .CASC_OUT(),
    //     .CNTVALUEOUT(),
    //     .DATAOUT(din_delayed),
    //     .CASC_IN(1'b0),
    //     .CASC_RETURN(1'b0),
    //     .CE(1'b0),
    //     .CLK(1'b0),
    //     .CNTVALUEIN(9'd0),
    //     .DATAIN(din),
    //     .EN_VTC(1'b0),
    //     .IDATAIN(1'b0),
    //     .INC(1'b0),
    //     .LOAD(1'b0),
    //     .RST(~idelay_rdy)
    // );

    ISERDESE3 #(
        .DATA_WIDTH(8),          //8-bit deserializer
        .FIFO_ENABLE("FALSE"),
        .FIFO_SYNC_MODE("FALSE"),
        .IS_CLK_B_INVERTED(1'b1), 
        .IS_CLK_INVERTED(1'b0),    
        .IS_RST_INVERTED(1'b1),
        .SIM_DEVICE("ULTRASCALE_PLUS")
    ) iserdes_inst (
        .FIFO_EMPTY(),
        .INTERNAL_DIVCLK(),
        .Q(ddr_data),        //deserialized output data
        .CLK(dco),           //high-speed DDR clock
        .CLKDIV(dco_div4),        //divided clock
        .CLK_B(dco),
        .D(din),
        .FIFO_RD_CLK(1'b0),
        .FIFO_RD_EN(1'b0),
        .RST(rstn)
    );

    AD9228_gearbox gearbox_8_to_12 (
        //inputs
        .rstn(rstn),
        .data_in_clk(dco_div4),
        .dco(dco),
        .fco(fco),
        .data_in(ddr_data_processed),

        //outputs
        .data_out(des_data),
        .data_valid_out(des_data_valid)
    );

endmodule