//Must be greater than 1ps/ps
`timescale 1ns/1ps

module AD9228_core_testbench #(
    parameter integer DATA_WIDTH = 12
) ();

    logic clk;
    logic sclk;
    logic rstn;

    always #1 clk = ~clk;
    always #6 sclk = ~sclk;

    logic d;
    logic fco;
    logic dco;
    logic [DATA_WIDTH-1:0] held_data;

    logic [DATA_WIDTH-1:0] des_data;

    AD9228_core AD9228_core_inst (
        .rstn (rstn),
        .clk (sclk),

        .din (d),
        .fco (fco),
        .dco (dco),

        .des_data (des_data)
    );

    task send_data (logic [DATA_WIDTH-1:0] data_to_send);
        for (int i = 0; i < DATA_WIDTH; i++) begin
            if (i < 6) begin
                fco = 1'b1;
            end
            else begin
                fco = 1'b0;
            end
            dco = ~dco;
            d = data_to_send[DATA_WIDTH - 1 - i];
            
            @(posedge clk or negedge clk);
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

    initial begin
        clk = 1'b0;
        rstn = 1'b1;
        held_data = 12'h555;

        d = 1'b0;
        fco = 1'b0;
        dco = 1'b0;
        sclk = 1'b0;
        #200;

        do_reset();
        #9;
        send_data(12'h0);
        send_data(12'h0);
        //#200;
        send_data(held_data);
        held_data = 12'b111111_111111;
        send_data(held_data);
        send_data(12'h0);
    end
endmodule