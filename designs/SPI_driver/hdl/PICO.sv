//This is the overview for the logic in this file
//Each packet of information comes in a byte, organized and sent to places on the following scheme
//serial in -> packed into byte sized message -> (if address pntr not set), set address pntr, (else), write the data and increment address pntr
//Top level module at the bottom to put everything together

//At each clock pulse, adds the serial input to the end of the current 8bit message
module s2p_shift_register (
input logic serial_in,
input logic sclk,
input logic rstn,
output logic [7:0] msg
);
    always_ff @(posedge sclk or negedge rstn) begin
        if (!rstn) begin
            msg <= 8'b0;
        end
        else begin
            msg <= {msg[6:0], serial_in};
        end
    end
endmodule

//outputs a flag signal when a msg is complete
module msg_flag_gen (
input logic sclk,
input logic rstn, //Reset input from the clock comparator
output logic msg_flag
);
    logic [2:0] count; //For the clock divider
    always_ff @(posedge sclk or negedge rstn) begin
        if (!rstn) begin
            count <= 3'b0;
        end
        else begin
            count <= count + 1;
        end
    end

    assign msg_flag = (count == 0);
endmodule

//Compares the internal clock and spi clock to see input stops coming in
//We set arbitrarily that 7 internal clock cycles of no sclk is when serial_in stops
module clock_comparator (
input logic sclk, //spi clock
input logic iclk, //internal clock from chip
input logic rstn, //external reset
output logic rstn_out //Goes to the buffer register to reset the clock divider
);

    logic [15:0] count; //how many iclk cycles since last sclk
    always_ff @(posedge iclk, posedge sclk, negedge rstn) begin
        if (!rstn) begin
            count <= 16'b0;
        end
        else if (sclk) begin
            count <= 16'b0;
        end
        else begin
            count <= count + 1;
        end
    end

    //reset logic based on count
    always_comb begin
        if (count == 7) begin
            rstn_out = 0;
        end
        else begin
            rstn_out = 1;
        end
    end
endmodule

//Takes serial input and outputs 8bit msg and reset signal if input stops
module s2p_module (
input logic serial_in,
input logic spi_clk,
input logic iclk, //internal clock for comparator
input logic rstn, //external reset
output logic [7:0] full_msg,
output logic sclk_stop_rstn, // reset not from clock comparator -> register
output logic msg_flag //to the read_write module
);
    logic full_rstn;
    assign full_rstn = rstn & sclk_stop_rstn;  

    s2p_shift_register shift_reg(.serial_in (serial_in), .sclk (spi_clk), .rstn (full_rstn), .msg (full_msg));
    msg_flag_gen buffer_reg(.sclk (spi_clk), .rstn (full_rstn), .msg_flag (msg_flag));
    clock_comparator comparator(.sclk (spi_clk), .iclk (iclk), .rstn (rstn), .rstn_out (sclk_stop_rstn));
endmodule

//Handles main read/write and address logic
//Needs to have a reset come in to initialize values
module read_write (
input logic [7:0] msg, //message from the s2p_module
input logic rstn, //external
input logic sclk_stop_rstn, //internal
input logic msg_flag, //flags when the msg from buffer reg changes
output logic [7:0] write_data, //the data that is output to be written
output logic [7:0] address_pointer //controls the mux which regulates reads out the chosen digital reg
);
    //Logic for addressing registers and writing
    always_ff @(posedge msg_flag or negedge rstn or negedge sclk_stop_rstn) begin 
        if (!rstn) begin
            write_data <= 8'b0; 
            address_pointer <= 8'b0;
        end
        else if (!sclk_stop_rstn) begin
            address_pointer <= 8'b0;
        end
        else begin
            if (address_pointer == '0) begin
                address_pointer <= msg;
                write_data <= 8'b0;
            end
            else begin
                write_data <= msg;
                address_pointer <= address_pointer + 1;
            end
        end
    end
endmodule

module PICO (
input logic serial_in, //Serial message data
input logic sclk, //spi clock
input logic iclk, //internal clock
input logic rstn, //external reset
output logic msg_flag,
output logic sclk_stop_rstn, //From the clock comparator
output logic [7:0] write_data, //Output data to write
output logic [7:0] mux_control_signal //Output control signal for POCI mux
); 
    logic [7:0] msgi; //internal message from s2p -> read_write
        
    s2p_module serial_to_eight_bit (
        .serial_in (serial_in),
        .spi_clk (sclk),
        .iclk (iclk),
        .rstn (rstn),
        .full_msg (msgi),
        .sclk_stop_rstn (sclk_stop_rstn),
        .msg_flag (msg_flag)
    );

    read_write eight_bit_to_output (
        .msg (msgi),
        .rstn (rstn),
        .sclk_stop_rstn (sclk_stop_rstn),
        .msg_flag (msg_flag),
        .write_data (write_data),
        .address_pointer (mux_control_signal)
    );
endmodule
