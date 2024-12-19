module serial_out_mux (
    input logic sclk,
    input logic rstn,
    input logic [7:0] raw_serial_out, //0-7 are channels
    input logic wr_serial_out, //W/R serial output
    input logic [7:0] mux_control_signal, //control signal
    output logic serial_out
);

    logic [7:0] addr_prev;

    always_ff @(posedge sclk) begin
        if (!rstn) begin
            addr_prev <= 8'b0;
        end
        else begin
            addr_prev <= mux_control_signal;
        end
    end

    always_comb begin
        if (!rstn) begin
            serial_out = 0;
        end
        else if (mux_control_signal <= 3) begin
            serial_out = wr_serial_out;
        end
        else if (mux_control_signal <= 10) begin
            serial_out = raw_serial_out[0];
        end
        else if (mux_control_signal <= 17) begin
            serial_out = raw_serial_out[1];
        end
        else if (mux_control_signal <= 24) begin
            serial_out = raw_serial_out[2];
        end
        else if (mux_control_signal <= 31) begin
            serial_out = raw_serial_out[3];
        end
        else if (mux_control_signal <= 38) begin
            serial_out = raw_serial_out[4];
        end
        else if (mux_control_signal <= 45) begin
            serial_out = raw_serial_out[5];
        end
        else if (mux_control_signal <= 52) begin
            serial_out = raw_serial_out[6];
        end
        else if (mux_control_signal <= 59) begin
            serial_out = raw_serial_out[7];
        end
        else if (mux_control_signal <= 65) begin
            serial_out = wr_serial_out;
        end
        else begin
            serial_out = 0;
        end
    end

endmodule