//12 bit to 8 bit gearbox, using fco_byte as the word alignment signal
//A full word looks like when fco has 12'b111111000000
module AD9228_gearbox #(
    parameter integer DATA_WIDTH = 12
)(
    input logic rstn,
    input logic dco_div4, //clk sync with data_in, is dco_div4 = dco/4
    input logic [7:0] fco_byte, //fco from SERDES after order inversion, clocked with dco_div4
    input logic [7:0] data_in,
    
    output logic [DATA_WIDTH-1:0] data_out,
    output logic data_valid_out
);

    logic [31:0] data_shift_reg;
    logic [23:0] fco_shift_reg;

    always_ff @(posedge dco_div4 or negedge rstn) begin
        if (!rstn) begin
            data_shift_reg <= '0;
            fco_shift_reg <= '0;
        end
        else begin
            data_shift_reg <= {data_shift_reg[23:0], data_in};
            fco_shift_reg <= {fco_shift_reg[15:0], fco_byte};
        end
    end

    always_comb begin //instantly outputs data 
        if (!rstn) begin
            data_out = '0;
            data_valid_out = 1'b0;
        end
        else begin
            case (12'hfc0) //corresponds to bit-string 111111000000, indicating completed word
                    fco_shift_reg[11:0] : begin
                        data_out = data_shift_reg[11:0];
                        data_valid_out = 1'b1;
                    end
                    fco_shift_reg[12:1] : begin
                        data_out = data_shift_reg[12:1];
                        data_valid_out = 1'b1;
                    end
                    fco_shift_reg[13:2] : begin
                        data_out = data_shift_reg[13:2];
                        data_valid_out = 1'b1;
                    end
                    fco_shift_reg[14:3] : begin
                        data_out = data_shift_reg[14:3];
                        data_valid_out = 1'b1;
                    end
                    fco_shift_reg[15:4] : begin
                        data_out = data_shift_reg[15:4];
                        data_valid_out = 1'b1;
                    end
                    fco_shift_reg[16:5] : begin
                        data_out = data_shift_reg[16:5];
                        data_valid_out = 1'b1;
                    end
                    fco_shift_reg[17:6] : begin
                        data_out = data_shift_reg[17:6];
                        data_valid_out = 1'b1;
                    end
                    fco_shift_reg[18:7] : begin
                        data_out = data_shift_reg[18:7];
                        data_valid_out = 1'b1;
                    end
                    // fco_shift_reg[19:8] : begin
                    //     data_out = data_shift_reg[19:8];
                    //     data_valid_out = 1'b1;
                    // end
                    // fco_shift_reg[20:9] : begin
                    //     data_out = data_shift_reg[20:9];
                    //     data_valid_out = 1'b1;
                    // end
                    // fco_shift_reg[21:10] : begin
                    //     data_out = data_shift_reg[21:10];
                    //     data_valid_out = 1'b1;
                    // end
                    // fco_shift_reg[22:11] : begin
                    //     data_out = data_shift_reg[22:11];
                    //     data_valid_out = 1'b1;
                    // end
                    // fco_shift_reg[23:12] : begin
                    //     data_out = data_shift_reg[23:12];
                    //     data_valid_out = 1'b1;
                    // end
                    default : begin //if no such matching case exists, send no data out
                        data_out = '0;
                        data_valid_out = 1'b0;
                    end
            endcase
        end
    end
endmodule