//Everything is done mod 12 on dco_phase_counter, should mentally think of a watchface where hours <=> dco_phase counter
//fco phase one falls somewhere between noon and 5, while phase two is shifted forward 6 hours
//similarly, dco_div4 phases fall between noon-3, 4-7, 8-11
module AD9228_gearbox #(
    parameter integer DATA_WIDTH = 12
)(
    input logic rstn,
    input logic dco_div4, //clk sync with data_in, is dco_div4 = dco/4
    input logic dco, //ddr data clock
    input logic fco, //used for word alignment, fco = dco/6
    input logic [7:0] data_in,
    
    output logic [DATA_WIDTH-1:0] data_out,
    output logic data_valid_out
);

    //phase trackers relative to arbitrary point
    //full cycle will repeat every 12 dco cycles since LCM(fco, dco_div4, dco) = LCM(6, 4, 1) = 12
    logic [3:0] dco_phase_counter; //runs from 0-11
    logic [3:0] fco_phase_one; //first fco phase relative to dco_phase_counter
    logic [3:0] fco_phase_two; //second fco phase, should be fco_phase_one + 6
    logic [3:0] dco_div4_phase_one; //first dco_div4 phase relative to dco_phase_counter
    logic [3:0] dco_div4_phase_two; //second dco_div4 phase, should be dco_div4_phase_one + 4
    logic [3:0] dco_div4_phase_three; //third dco_div4 phase, should be dco_div4_phase_one + 8

    //one dco delayed signals
    logic prev_dco_div4;
    logic prev_fco;
    logic dco_div4_sync;
    logic fco_sync;
    logic fco_rising_edge;
    logic dco_div4_rising_edge;

    //things to check locking phase
    logic phase_locked; //goes to 1 when all phases are fixed over two cycles
    logic [3:0] fco_phase_one_d1; //delayed by one full cycle to check lock
    logic [3:0] dco_div4_phase_one_d1; //delayed by one full cycle

    //objects related to the gearbox itself
    logic [47:0] shift_reg; //holds two cycles worth of data to make life easier

    always_comb begin
        fco_phase_two = fco_phase_one + 6;
        dco_div4_phase_two = dco_div4_phase_one + 4;
        dco_div4_phase_three = dco_div4_phase_one + 8;
    end

    assign phase_locked = (fco_phase_one == fco_phase_one_d1) && (dco_div4_phase_one == dco_div4_phase_one_d1);
    assign fco_rising_edge = fco && !prev_fco;
    assign dco_div4_rising_edge = dco_div4 && !prev_dco_div4;

    //phase tracking and locking logic
    always_ff @(posedge dco or negedge rstn) begin
        if (!rstn) begin
            dco_phase_counter <= '0;
            fco_phase_one <= 4'd14;
            dco_div4_phase_one <= 4'd14;
            fco_phase_one_d1 <= 4'd15; //reset to something different than fco_phase_one to not assign phase_locked too early
            dco_div4_phase_one_d1 <= 4'd15; //reset to something different than dco_div4_phase_one
            
            prev_dco_div4 <= 0;
            prev_fco <= 0;
            dco_div4_sync <= 0;
            fco_sync <= 0;
        end
        else begin
            //tracking fco and dco_div4 one dco back for rising edge
            dco_div4_sync <= dco_div4;
            fco_sync <= fco;
            prev_dco_div4 <= dco_div4_sync;
            prev_fco <= fco_sync;

            //handles dco_phase_counter
            dco_phase_counter <= (dco_phase_counter + 1) % 12;

            //tracks the phases of fco and dco_div4 on previous full_cycle
            //tracked at last dco to not intersect with the reset values
            if (dco_phase_counter == 4'd7) begin
                fco_phase_one_d1 <= fco_phase_one;
                dco_div4_phase_one_d1 <= dco_div4_phase_one;
            end

            //tracks phase of dco_div4
            if (dco_phase_counter < 4'd4 && //want the first phase to be between noon and 3
                dco_div4_rising_edge && 
                dco_div4_phase_one != (dco_phase_counter-1) && //don't want to consider falling edge of dco_div4_rising_edge
                !(dco_div4_phase_three == 4'hb && dco_phase_counter == '0) //fixes a rollover bug
            ) begin
                dco_div4_phase_one <= dco_phase_counter;
            end

            //tracks phase of fco
            if (dco_phase_counter < 4'd6 && //want first phase in first half
                fco_rising_edge && 
                fco_phase_one != (dco_phase_counter-1) && //only want to consider rising edge 
                !(fco_phase_two == 4'hb && dco_phase_counter == '0) //fixes a rollover bug
            ) begin
                fco_phase_one <= dco_phase_counter;
            end
        end
    end

    //simple shift register to always capture data
    always_ff @(posedge dco_div4 or negedge rstn) begin
        if (!rstn) begin
            shift_reg <= '0;
        end
        else begin
            shift_reg <= {shift_reg[39:0], data_in}; //shifting in data always, even when phases aren't understood
        end
    end

    //logic to output data from shift register properly
    always_ff @(posedge dco_div4 or negedge rstn) begin
        if (!rstn) begin
            data_out = '0;
            data_valid_out = 1'b0;
        end
        else begin
            if (!phase_locked) begin
                data_out = '0;
                data_valid_out = 1'b0;
            end
            else begin
                //handle which dco_div4 third of the full cycle we are in
                if (dco_phase_counter >= dco_div4_phase_one && dco_phase_counter < dco_div4_phase_two) begin //dco_phase in the first third
                    if (fco_phase_one >= dco_div4_phase_one && fco_phase_one < dco_div4_phase_two) begin //catching most cases where fco starts in first third
                        data_out = shift_reg[19 + 2*(dco_div4_phase_two-fco_phase_one) -: DATA_WIDTH]; //add 16 because we are finding data started more than two cycles back
                        // add second term to account for number of bits between word start and two cycles back
                        data_valid_out = 1'b1;
                    end
                    else if (fco_phase_two < dco_div4_phase_two) begin //catches edge case for dco_div4_phase_two = 7, fco_phase_two = 6
                        data_out = shift_reg[19 + 2*(dco_div4_phase_two-fco_phase_two) -: DATA_WIDTH]; //same logic as above
                        data_valid_out = 1'b1;
                    end
                    else begin //fco doesn't start in this third
                        data_out = '0;
                        data_valid_out = 1'b0;
                    end
                end

                else if (dco_phase_counter >= dco_div4_phase_two && dco_phase_counter < dco_div4_phase_three) begin //second third 
                    //same idea as above, catch when word starts in second third
                    if (fco_phase_one >= dco_div4_phase_two) begin //edge case: fco_phase_one = 4,5, dco_div4_phase_two = 4,5
                        data_out = shift_reg[19 + 2*(dco_div4_phase_three - fco_phase_one) -: DATA_WIDTH]; //same logic, just think of the clock
                        data_valid_out = 1'b1;
                    end
                    else if (fco_phase_two >= dco_div4_phase_two && fco_phase_two < dco_div4_phase_three) begin //main case for fco in second third
                        data_out = shift_reg[19 + 2*(dco_div4_phase_three - fco_phase_two) -: DATA_WIDTH]; //same logic, just think of the clock
                        data_valid_out = 1'b1;
                    end
                    else begin //fco doesn't happen in second third
                        data_out = '0;
                        data_valid_out = 1'b0;
                    end
                end 

                else begin //final third
                    //same logic for final third
                    if (fco_phase_two >= dco_div4_phase_three) begin 
                        data_out = shift_reg[15 + 2*(1 + dco_div4_phase_one) + 2*(11 - dco_div4_phase_three) -: DATA_WIDTH]; //this one is strange because we are mod 12
                        //we need to get back to dco_counter=0 with (1+dco_div4_phase_one), and then get to the fco with (11-dco_div4_phase_three) 
                        data_valid_out = 1'b1;
                    end
                    else if (fco_phase_one < dco_div4_phase_one) begin //if fco starts in second part of final third
                        data_out = shift_reg[19 + 2*(dco_div4_phase_one - fco_phase_one) -: DATA_WIDTH];
                        data_valid_out = 1'b1;
                    end
                    else begin
                        data_out = '0;
                        data_valid_out = 1'b0;
                    end
                end
            end
        end
    end

endmodule