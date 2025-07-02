//Must be greater than 1ps/ps
`timescale 1ns/1ps

module AD9228_gearbox_testbench #(
    DATA_OUT_WIDTH = 12,
    DATA_IN_WIDTH = 8,
    FULL_DATA_WIDTH = 72
) ();

    //simulation signals
    logic clk;
    logic [FULL_DATA_WIDTH-1:0] full_data;

    logic rstn;
    logic dco_div4;
    logic dco;
    logic fco;
    logic [DATA_IN_WIDTH-1:0] data_in;

    logic [DATA_OUT_WIDTH-1:0] data_out;
    logic data_valid_out;

    AD9228_gearbox DUT (
        .rstn (rstn),
        .dco_div4(dco_div4),
        .dco(dco),
        .fco(fco),
        .data_in(data_in),

        .data_out(data_out),
        .data_valid_out(data_valid_out)
    );

    always #1 clk = ~clk;

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
        full_data = 'b10101010_10100000_00000001_11111111_11110000_00000001_10101010_10100000_00111111;
        clk = 0;
        dco = 0;
        fco = 0;
        dco_div4 = 0;
        data_in = '0;

        do_reset();

        add_dco_phase_shift(2);

        for (int dco_counter = 0; dco_counter <= FULL_DATA_WIDTH; dco_counter++) begin
            @(posedge clk)
            dco = 1;

            //logic for /4 divider
            if (dco_counter % 4 < 2) begin
                dco_div4 = 1;
            end
            else begin 
                dco_div4 = 0;
            end

            //logic for frame clock
            if (dco_counter % 6 < 3) begin
                fco = 1;
            end 
            else begin
                fco = 0;
            end


            //logic for data_in
            if(dco_counter % 4 == 0 && dco_counter != 0) begin
                data_in = full_data[FULL_DATA_WIDTH-1 - 2*(dco_counter-4) -: 8]; //Data should be clocked out in bytes MSB to LSB
            end

            @(negedge clk)
            dco = 0;
        end

        $finish;
    end
endmodule