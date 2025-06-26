module AD9228_gearbox #(
    parameter integer DATA_WIDTH = 12
)(
    input logic rstn,
    input logic data_in_clk, //clk sync with data_in, dco_div4
    input logic dco,
    input logic fco, //used for word alignment
    input logic [7:0] data_in,
    input logic data_valid_in,
    
    output logic [DATA_WIDTH-1:0] data_out,
    output logic data_valid_out
);

    logic [31:0] shift_register;  //8 bits larger than strictly necessary for ease
    logic [5:0] bit_count;        //counts num of valid bits in shift register
    
    typedef enum logic [1:0] {
        IDLE,
        ACCUMULATE,
        OUTPUT_READY
    } state_t;
    
    state_t current_state;
    
    //shift register for gearbox
    always_ff @(posedge data_in_clk or negedge rstn) begin
        if (!rstn) begin
            current_state <= IDLE;
            shift_register <= 32'b0;
            bit_count <= 6'b0;
            data_out <= 'b0;
            data_valid_out <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    data_valid_out <= 1'b0;
                    if (data_valid_in) begin
                        shift_register <= {24'b0, data_in};
                        bit_count <= 6'd8;
                        current_state <= ACCUMULATE;
                    end else begin
                        bit_count <= 6'b0;
                        current_state <= IDLE;
                    end
                end
                
                ACCUMULATE: begin
                    data_valid_out <= 1'b0;
                    if (data_valid_in) begin
                        shift_register <= {shift_register[23:0], data_in};
                        bit_count <= bit_count + 8;
                    end

                    //handles if there are enough bits to output yet
                    if (bit_count >= 12) begin
                        current_state <= OUTPUT_READY;
                    end
                    else begin
                        current_state <= ACCUMULATE;
                    end
                end
                
                OUTPUT_READY: begin
                    //put oldest 12 bits out
                    data_out <= shift_register[bit_count-1 -: 12];
                    data_valid_out <= 1'b1;
                    
                    //capture new data during output and removes old bits
                    if (data_valid_in) begin
                        if (bit_count == 6'd12) begin //handles the special case where putting the data out empties the shift register
                            shift_register <= {24'd0, data_in};
                        end
                        else begin
                            shift_register <= {4'b0, shift_register[19:0], data_in};
                        end

                        if ((bit_count-12+8) >= 12) begin //if there are still enough bits left after cleaning to output, continue
                            current_state <= OUTPUT_READY;
                        end
                        else begin
                            current_state <= ACCUMULATE;
                        end

                        bit_count <= bit_count - 12 + 8; //removes # emptied bits (12) and adds # added bits (8)
                    end
                    else begin
                        if (bit_count == 6'd12) begin //completely emptied shift_reg
                            shift_register <= 32'd0;
                        end
                        else begin
                            shift_register <= {12'b0, shift_register[19:0]};
                        end
                        bit_count <= bit_count - 12;

                        if ((bit_count-12) >= 12) begin //if there are still enough bits left after cleaning to output, continue
                            current_state <= OUTPUT_READY;
                        end
                        else begin
                            current_state <= IDLE; //no valid data in
                        end
                    end
                end
            endcase
        end
    end
endmodule