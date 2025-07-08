//Must be greater than 1ps/ps
`timescale 1ns/1ps

module AD9228_core_testbench #(
    parameter integer DATA_WIDTH = 12
) ();

    logic clk;
    logic rstn;

    always #1 clk = ~clk;

    logic d;
    logic fco;
    logic [7:0] fco_byte; //should come from SERDES
    logic dco;
    logic dco_div4;
    logic [DATA_WIDTH-1:0] held_data;

    logic [DATA_WIDTH-1:0] des_data;
    logic des_data_valid;

    AD9228_core_SERDES DUT (
        .rstn (rstn),

        .din (d),
        .fco_byte (fco_byte),
        .dco (dco),
        .dco_div4 (dco_div4),

        .des_data (des_data),
        .des_data_valid (des_data_valid)
    );

    //to generate fco_byte properly
    ISERDESE3 #(
        .DATA_WIDTH(8),          //8-bit deserializer
        .FIFO_ENABLE("FALSE"),
        .FIFO_SYNC_MODE("FALSE"),
        .IS_CLK_B_INVERTED(1'b1), 
        .IS_CLK_INVERTED(1'b0),    
        .IS_RST_INVERTED(1'b1),
        .SIM_DEVICE("ULTRASCALE_PLUS")
    ) fco_serdes (
        .FIFO_EMPTY(),
        .INTERNAL_DIVCLK(),
        .Q(fco_byte),        //deserialized output data
        .CLK(dco),           //high-speed DDR clock
        .CLKDIV(dco_div4),        //divided clock
        .CLK_B(dco),
        .D(fco),
        .FIFO_RD_CLK(1'b0),
        .FIFO_RD_EN(1'b0),
        .RST(rstn)
    );

    //generate dco_div4 accurately
    BUFGCE_DIV #(
        .BUFGCE_DIVIDE(4),      //divide by 4 for SERDES running in 8bit ddr config
        .IS_CE_INVERTED(1'b0),
        .IS_CLR_INVERTED(1'b1),
        .IS_I_INVERTED(1'b0)
    ) dco_div4_inst (
        .O(dco_div4),           //divided clock out
        .CE(1'b1),              //always running clock
        .CLR(rstn),            
        .I(dco)                 //data clock
    );

    task send_data (logic [DATA_WIDTH-1:0] data_to_send);
        for (int i = 0; i < DATA_WIDTH; i++) begin
            @(posedge clk or negedge clk);
            if (i < 6) begin
                fco = 1'b1;
            end
            else begin
                fco = 1'b0;
            end
            dco = ~(i % 2);
            d = data_to_send[DATA_WIDTH - 1 - i];
        end
    endtask

    task do_reset ();
        rstn = 1;
        @(posedge clk);
        @(negedge clk);
        rstn = 0;
        @(posedge clk);
        @(negedge clk);
        rstn = 1;

        $display("External Reset -------------------------------------------------------------------------------------------------------------------------");
    endtask

    task add_dco_phase_shift (int phase_number);
        for (int i = 0; i < phase_number; i++) begin
            @(posedge clk);
            dco = 1;
            @(negedge clk);
            dco = 0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rstn = 1'b1;
        held_data = 12'h555;

        d = 1'b0;
        fco = 1'b0;
        dco = 1'b0;
        #200;

        do_reset();
        #200;

        add_dco_phase_shift(0);

        send_data(12'h000);
        send_data(12'h000);
        send_data(12'h000);
        send_data(12'hfff);
        send_data(12'h001);
        send_data(12'hfff);
        send_data(12'h001);
        send_data(12'h03f);
        send_data(12'h001);
    end
endmodule