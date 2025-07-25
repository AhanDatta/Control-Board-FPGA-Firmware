module AD9228_core_SERDES #(
    parameter logic DIN_INVERTED = 0,
    parameter integer DATA_WIDTH = 12
) (
    input logic rstn, //should be sync to dco_div4

    //adc inputs
    input logic din,
    input logic [7:0] fco_byte, //should come directly from SERDES output
    input logic dco,  //DDR clock for data
    input logic dco_div4, //dco divided by four for SERDES

    output logic [DATA_WIDTH-1:0] des_data,
    output logic des_data_valid
);

    logic [7:0] ddr_data;  //8 bits collected over 4 DDR cycles by SERDES
    logic [7:0] ddr_data_processed; //accounts for DIN_INVERTED and SERDES bit-order inversion
    logic [7:0] fco_byte_ordered; //accounts for reverse bit-ordering from SERDES
    logic [7:0] ddr_data_pipelined; //pipelined versions of data and fco to satisfy hold timing requirements
    logic [7:0] fco_byte_pipelined;

    //handles DIN_INVERTED
    generate 
        if (DIN_INVERTED) begin : din_gen_inv
            assign ddr_data_processed = {<<{~ddr_data}}; //bitstreaming handles order inversion
        end 
        else begin : din_gen_normal
            assign ddr_data_processed = {<<{ddr_data}};
        end
    endgenerate

    assign fco_byte_ordered = {<<{fco_byte}};

    always_ff @(posedge dco_div4 or negedge rstn) begin
        if (!rstn) begin
            ddr_data_pipelined <= '0;
            fco_byte_pipelined <= '0;
        end
        else begin
            ddr_data_pipelined <= ddr_data_processed;
            fco_byte_pipelined <= fco_byte_ordered;
        end
    end

    ISERDESE3 #(
        .DATA_WIDTH(8),          //8-bit deserializer
        .FIFO_ENABLE("FALSE"),
        .FIFO_SYNC_MODE("FALSE"),
        .IS_CLK_B_INVERTED(1'b1), 
        .IS_CLK_INVERTED(1'b0),    
        .IS_RST_INVERTED(1'b1),
        .SIM_DEVICE("ULTRASCALE_PLUS")
    ) din_serdes (
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
        .dco_div4(dco_div4),
        .fco_byte (fco_byte_pipelined),
        .data_in(ddr_data_pipelined),

        //outputs
        .data_out(des_data),
        .data_valid_out(des_data_valid)
    );

endmodule