typedef enum logic [3:0] {
        STATE_INIT, // All counters are reset to 0 and stopped, and all SCAs are stopped.
        STATE_STOPPED, // All SCAs and counters are stopped, but the counters are left at their current value.
        STATE_SAMPLING_A, // sample the fast buffer A. The length of the buffer is 3.2ns.
        STATE_SAMPLING_B, // sample the fast buffer B.
        STATE_SAMPLING_C, // sample the fast buffer C.
        STATE_SAMPLING_D, // sample the fast buffer D.
        STATE_SAMPLING_E, // sample the slow buffer.
        STATE_SAMPLING_A_AND_B, // sample the fast buffers A and B.
        //Note that the writing strobe at the last capacitor of bank A is fed to that of the first capacitor of bank B,
        //which avails wraparoundless sampling.
        //The two banks effectively act as one buffer of length 6.4ns.
        STATE_SAMPLING_C_AND_D, // sample the fast buffers C and D.
        STATE_SAMPLING_ALL, // sample all fast buffers. The length of the buffer is 12.8ns.
        STATE_READOUT //NOTE: readout is not implemented in this module yet. This state is only used for simulation purposes.
    } state_t;

typedef enum logic [1:0] {
    MODE_SAMPLE1,
    MODE_SAMPLE2,
    MODE_SAMPLE4
} smode_t;
module PSEC5_CH_DIGITAL (
    input logic INST_START,
    input logic INST_STOP,
    input logic INST_READOUT,
    input logic RSTB,
    input logic DISCRIMINATOR_OUTPUT, // This is the unsync'ed input from the discriminator, which is in the analog part of the PSEC5.
    input logic SPI_CLK, //I moved some of the spi shift registers into this module, for the sake of speed and simplicity.
    input logic [9:0] CA, //These are counter values.
    input logic [9:0] CB,
    input logic [9:0] CC,
    input logic [9:0] CD,
    input logic [9:0] CE,
    input smode_t MODE,
    input logic DISCRIMINATOR_POLARITY,
    input logic [2:0] SELECT_REG,
    input logic [4:0] TRIG_DELAY,
    input logic FCLK,
    //NOTE: The final output of the module has to be synchronized to the 5GHz clock nonetheless, to avoid metastability issues. This is not implemented in this module yet.
    output logic STOP_REQUEST,
    output logic TRIGGERA,
    output logic TRIGGERB,
    output logic TRIGGERC,
    output logic TRIGGERD,
    output logic TRIGGERE,
    output logic TRIGGERAC,
    output logic TRIGGERBC,
    output logic TRIGGERCC,
    output logic TRIGGERDC,
    output logic CNT_SER
);  
    state_t current_state;
    //logic [7:0] cbuffer;
    logic [31:0] trig_shift_reg;
    logic [55:0] ctmp;
    logic start1;
    logic start2;
    logic start4;
    logic trigger;
    logic [2:0] trigger_cnt; //# of legitimate trigger fires. 
    logic premature_trigger;
    logic [2:0] ser_pos;

    always_ff @(posedge FCLK, posedge INST_START) begin
        if(INST_START) begin
          trig_shift_reg <= 32'b1; //Zero all registers except the first bit. After 6.4ns, when the bit reaches the last register, release the premature_trigger.
          premature_trigger <= 1;
        end
        else begin
          trig_shift_reg <= {trig_shift_reg[30:0], DISCRIMINATOR_OUTPUT};
          if(trig_shift_reg[31]) begin
            premature_trigger <= 0;
          end
        end
    end
    always_comb begin
        if (INST_START) begin
           case (MODE) 
                    MODE_SAMPLE1: 
                        begin
                            start1 = 1;
                            start2 = 0;
                            start4 = 0;
                        end
                    MODE_SAMPLE2: 
                        begin
                            start1 = 0;
                            start2 = 1;
                            start4 = 0;
                        end
                    MODE_SAMPLE4: 
                        begin
                            start1 = 0;
                            start2 = 0;
                            start4 = 1;
                        end 
                    default: // Handle any other states if necessary
                        begin
                            // Default behavior
                            start1 = 0;
                            start2 = 0;
                            start4 = 1;
                        end
                endcase 
        end
        else begin
            start1 = 0;
            start2 = 0;
            start4 = 0;

        end
    end

    always_comb begin
        case (current_state)
            STATE_STOPPED: begin
                trigger = 0;
            end
            STATE_INIT: begin
                trigger = 0;
            end
            STATE_READOUT: begin
                trigger = 0;
            end
            default: begin
                if (TRIG_DELAY == 5'b0) begin
                    trigger = (DISCRIMINATOR_OUTPUT ^ DISCRIMINATOR_POLARITY) & (!premature_trigger);
                end
                else begin
                    trigger = (trig_shift_reg[TRIG_DELAY] ^ DISCRIMINATOR_POLARITY) & (!premature_trigger);
                end
                
            end
        
        endcase
        
    end

    always_ff @(posedge trigger, posedge INST_START) begin
        if (INST_START) begin
            STOP_REQUEST <= 0;
        end
        else begin
            STOP_REQUEST <= 1;
        end
    end

    always_ff @(posedge trigger, negedge RSTB, posedge start1, posedge start2, posedge start4, posedge INST_STOP, posedge INST_READOUT) begin
        if (!RSTB) begin
            current_state <= STATE_INIT;
        end
        else begin
            if (start1) begin 
                current_state <= STATE_SAMPLING_A;
                trigger_cnt <= 3'b0;
            end
            else begin 
                if (start2) begin 
                    current_state <= STATE_SAMPLING_A_AND_B; 
                    trigger_cnt <= 3'b0;
                end
                else begin 
                    if (start4) begin 
                        current_state <= STATE_SAMPLING_ALL;
                        trigger_cnt <= 3'b0;
                    end
                    else begin 
                        if (INST_STOP) begin
                            current_state <= STATE_STOPPED;
                        end
                        else begin 
                            if (INST_READOUT) current_state <= STATE_READOUT;
                            else begin 
                                case (current_state)
                                    STATE_SAMPLING_A: begin
                                        // If the discriminator output is present, start sampling the next fast buffer.
                                        current_state <= STATE_SAMPLING_B;
                                        trigger_cnt <= 3'b001;
                                    end
                                    STATE_SAMPLING_B: begin
                                        // If the discriminator output is present, start sampling the next fast buffer.
                                        current_state <= STATE_SAMPLING_C;
                                        trigger_cnt <= 3'b010;
                                    end
                                    STATE_SAMPLING_C: begin
                                        // If the discriminator output is present, start sampling the next fast buffer.
                                        current_state <= STATE_SAMPLING_D;
                                        trigger_cnt <= 3'b011;
                                    end
                                    STATE_SAMPLING_D: begin
                                        // If the discriminator output is present, finish sampling the fast buffers but keep sampling the slow buffer.
                                        current_state <= STATE_SAMPLING_E;
                                        trigger_cnt <= 3'b100;
                                    end
                                    STATE_SAMPLING_A_AND_B: begin
                                        // If the discriminator output is present, start sampling the next two fast buffers.
                                        current_state <= STATE_SAMPLING_C_AND_D;
                                        trigger_cnt <= 3'b001;
                                    end
                                    STATE_SAMPLING_C_AND_D: begin
                                        // If the discriminator output is present, finish sampling the fast buffers but keep sampling the slow buffer.
                                        current_state <= STATE_SAMPLING_E;
                                        trigger_cnt <= 3'b010;
                                    end
                                    STATE_SAMPLING_ALL: begin
                                        // If the discriminator output is present, finish sampling the fast buffers but keep sampling the slow buffer.
                                        current_state <= STATE_SAMPLING_E;
                                        trigger_cnt <= 3'b001;
                                    end
                                    STATE_INIT: begin
                                        current_state <= STATE_INIT;
                                    end
                                    STATE_READOUT: begin
                                        current_state <= STATE_READOUT;
                                    end
                                    STATE_STOPPED: begin
                                        current_state <= STATE_STOPPED;
                                    end
                                    STATE_SAMPLING_E: begin
                                        // This state is reached when the fast buffers are done sampling. The state machine will stay in this state until a command is given.
                                        current_state <= STATE_SAMPLING_E;
                                    end
                                    default: // Handle any other states if necessary
                                        begin
                                            // Default behavior
                                            current_state <= STATE_STOPPED;
                                        end
                                endcase
                            end
                        end
                    end
                end
            end
        end
    end

    always_ff @(posedge INST_READOUT) begin
        ctmp <= {<<{3'b000, trigger_cnt, CE, CD, CC, CB, CA}}; //56 bits total.
    end


    always_ff @(posedge SPI_CLK, negedge RSTB) begin
        if (!RSTB) begin
            ser_pos <= 0;
        end
        else begin //Default behavior when SPI_CLK is high
            for (int i = 0; i < 7; i++) begin
                for (int j = 0; j < 8; j++) begin
                    if(SELECT_REG == i && ser_pos == j)
                        CNT_SER <= ctmp[i*8+j];
                end
            end
          ser_pos <= ser_pos + 1;
        end
    end

    always_comb begin
        //Update the control latches based on the current state.
        case (current_state)
        STATE_INIT:
            begin
                TRIGGERA = 1;
                TRIGGERAC = 1;
                TRIGGERB = 1;
                TRIGGERBC = 1;
                TRIGGERC = 1;
                TRIGGERCC = 1;
                TRIGGERD = 1;
                TRIGGERDC = 1;
                TRIGGERE = 1;
            end
        STATE_STOPPED:
            begin
                TRIGGERA = 1;
                TRIGGERAC = 1;
                TRIGGERB = 1;
                TRIGGERBC = 1;
                TRIGGERC = 1;
                TRIGGERCC = 1;
                TRIGGERD = 1;
                TRIGGERDC = 1;
                TRIGGERE = 1;
            end
        STATE_READOUT:
            begin
                TRIGGERA = 1;
                TRIGGERAC = 1;
                TRIGGERB = 1;
                TRIGGERBC = 1;
                TRIGGERC = 1;
                TRIGGERCC = 1;
                TRIGGERD = 1;
                TRIGGERDC = 1;
                TRIGGERE = 1;
            end
        STATE_SAMPLING_A:
            begin
                TRIGGERA = 0;
                TRIGGERAC = 0;
                TRIGGERB = 1;
                TRIGGERBC = 0;
                TRIGGERC = 1;
                TRIGGERCC = 0;
                TRIGGERD = 1;
                TRIGGERDC = 0;
                TRIGGERE = 0;
            end
        STATE_SAMPLING_B:
            begin
                TRIGGERA = 1;
                TRIGGERAC = 1;
                TRIGGERB = 0;
                TRIGGERBC = 0;
                TRIGGERC = 1;
                TRIGGERCC = 0;
                TRIGGERD = 1;
                TRIGGERDC = 0;
                TRIGGERE = 0;
            end
        STATE_SAMPLING_C:
            begin
                TRIGGERA = 1;
                TRIGGERAC = 1;
                TRIGGERB = 1;
                TRIGGERBC = 1;
                TRIGGERC = 0;
                TRIGGERCC = 0;
                TRIGGERD = 1;
                TRIGGERDC = 0;
                TRIGGERE = 0;
            end
        STATE_SAMPLING_D:
            begin
                TRIGGERA = 1;
                TRIGGERAC = 1;
                TRIGGERB = 1;
                TRIGGERBC = 1;
                TRIGGERC = 1;
                TRIGGERCC = 1;
                TRIGGERD = 0;
                TRIGGERDC = 0;
                TRIGGERE = 0;
            end
        STATE_SAMPLING_E:
            begin
                TRIGGERA = 1;
                TRIGGERAC = 1;
                TRIGGERB = 1;
                TRIGGERBC = 1;
                TRIGGERC = 1;
                TRIGGERCC = 1;
                TRIGGERD = 1;
                TRIGGERDC = 1;
                TRIGGERE = 0;
            end
        STATE_SAMPLING_A_AND_B:
            begin
                TRIGGERA = 0;
                TRIGGERAC = 0;
                TRIGGERB = 0;
                TRIGGERBC = 0;
                TRIGGERC = 1;
                TRIGGERCC = 0;
                TRIGGERD = 1;
                TRIGGERDC = 0;
                TRIGGERE = 0;
            end
        STATE_SAMPLING_C_AND_D:
            begin
                TRIGGERA = 1;
                TRIGGERAC = 1;
                TRIGGERB = 1;
                TRIGGERBC = 1;
                TRIGGERC = 0;
                TRIGGERCC = 0;
                TRIGGERD = 0;
                TRIGGERDC = 0;
                TRIGGERE = 0;
            end
        STATE_SAMPLING_ALL:
         begin
                TRIGGERA = 0;
                TRIGGERAC = 0;
                TRIGGERB = 0;
                TRIGGERBC = 0;
                TRIGGERC = 0;
                TRIGGERCC = 0;
                TRIGGERD = 0;
                TRIGGERDC = 0;
                TRIGGERE = 0;
            end
        default: // Handle any other states if necessary
            begin
                // Default behavior
                TRIGGERA = 1;
                TRIGGERAC = 1;
                TRIGGERB = 1;
                TRIGGERBC = 1;
                TRIGGERC = 1;
                TRIGGERCC = 1;
                TRIGGERD = 1;
                TRIGGERDC = 1;
                TRIGGERE = 1;
            end

        endcase
    end



endmodule
