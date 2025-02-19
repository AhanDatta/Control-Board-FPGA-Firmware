`timescale 1ns/1ps

module LTC2600_write_testbench #(
    parameter integer DATA_WIDTH = 16
)();

    logic rstn;
    logic clk;

    logic send_new_cmd;
    logic [3:0] command;
    logic [3:0] address;
    logic [DATA_WIDTH-1:0] fake_data;

    logic sck;
    logic sdi;
    logic csb;
    logic clrb;

    logic write_complete;

    LTC2600_write DUT (
        .rstn (rstn),
        .clk (clk),

        .send_new_cmd (send_new_cmd),
        .command (command),
        .address (address),
        .data (fake_data),

        .sck (sck),
        .sdi (sdi),
        .csb (csb),
        .clrb (clrb),

        .write_complete (write_complete)
    );

    always #10 clk = ~clk;

    task ext_reset ();
        rstn = 0;
        @(posedge clk);
        @(negedge clk);
        rstn = 1;
        $display("External Reset -------------------------------------------------------------------------------------------------------------------------");
    endtask

    task send_data (logic [3:0] cmd, logic [3:0] addr, logic [DATA_WIDTH-1:0] data);
        command = cmd;
        address = addr;
        fake_data = data;

        @(posedge clk);
        @(negedge clk);

        send_new_cmd = 1'b1;

        @(posedge clk);
        @(negedge clk);
        @(posedge clk);
        @(negedge clk);
        @(posedge clk);
        @(negedge clk);

        send_new_cmd = 1'b0;
    endtask

    initial begin
        rstn = 1'b1;
        clk = 1'b0;
        
        send_new_cmd = 1'b0;
        command = '0;
        address = '0;
        fake_data = '0;
        
        ext_reset();

        send_data(4'b0001, 4'b1000, 16'haaaa);
    end

endmodule