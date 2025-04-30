module ODELAY_set_ctrl #(
        parameter N = 0
    )
    (
        input wire clk160,
        
        input wire [8:0] delay_target,
        input wire [8:0] delay_out,
        
        output reg [8:0] delay_set_value = 0,
        output wire delay_wr,
        output wire delay_ready,
        
        input wire rstb

    );
    
    // state machine to govern setting IDELAY delay setting
    // because this cannot be changed by more than 8 at a time
    localparam STATE_IDELAY_IDLE    = 4'h0;
    localparam STATE_IDELAY_RD_CNT  = 4'h1;
    localparam STATE_IDELAY_CHK_CNT = 4'h2;
    localparam STATE_IDELAY_CALC    = 4'h3;
    localparam STATE_IDELAY_SET_CNT = 4'h4;
    localparam STATE_IDELAY_WAIT1   = 4'h5;
    localparam STATE_IDELAY_WAIT2   = 4'h6;
    localparam STATE_IDELAY_WAIT3   = 4'h7;
    localparam STATE_IDELAY_WAIT4   = 4'h8;
    
    reg [3:0] idelay_state = STATE_IDELAY_IDLE;
    reg [8:0] idelay_cnt_read_hold = 0;
    reg [8:0] idelay_cnt_write_hold = 0;
    reg delay_wr_int;
    
    assign delay_wr = delay_wr_int && !delay_ready;
    
    wire signed [9:0] idelay_cnt_read_hold_s;
    wire signed [9:0] idelay_cnt_write_hold_s;
    wire signed [9:0] delay_diff;
    assign idelay_cnt_read_hold_s = $signed({1'b0,idelay_cnt_read_hold});
    assign idelay_cnt_write_hold_s = $signed({1'b0,idelay_cnt_write_hold});
    assign delay_diff = idelay_cnt_write_hold_s - idelay_cnt_read_hold_s;
    
    assign delay_ready = (delay_target == delay_out);
    generate
    
        always @(posedge clk160)
        begin
            if(!rstb)
            begin
                idelay_state <= STATE_IDELAY_IDLE;
                delay_wr_int <= 0;
                idelay_cnt_read_hold <= 0;
                idelay_cnt_write_hold <= 0;
                delay_set_value <= 0;
            end
            else
            case(idelay_state)
                STATE_IDELAY_IDLE:
                begin
                    idelay_state <= STATE_IDELAY_CHK_CNT;
                end
                
                STATE_IDELAY_CHK_CNT:
                begin
                    idelay_state <= STATE_IDELAY_CALC;
                    idelay_cnt_read_hold <= delay_out;
                    idelay_cnt_write_hold <= delay_target;
                end
                
                STATE_IDELAY_CALC:
                begin
                    idelay_state <= STATE_IDELAY_SET_CNT;
                    delay_wr_int <= 1;
                    
                    if(N == 1)
                    begin
                        delay_set_value <= $signed(idelay_cnt_read_hold) + delay_diff;
                    end
                    else
                    begin
                        if(delay_diff >= 8 || delay_diff <= -8)
                        begin
                            delay_set_value <= $signed(idelay_cnt_read_hold) + ((delay_diff > 0)?(10'd8):(-10'd8));
                        end
                        else
                        begin
                            delay_set_value <= $signed(idelay_cnt_read_hold) + delay_diff;
                        end
                    end
                end
                
                STATE_IDELAY_SET_CNT:
                begin
                    idelay_state <= STATE_IDELAY_WAIT1;
                    delay_wr_int <= 0;
                end
                
                STATE_IDELAY_WAIT1: idelay_state <= STATE_IDELAY_WAIT2;            
                STATE_IDELAY_WAIT2: idelay_state <= STATE_IDELAY_WAIT3;
                STATE_IDELAY_WAIT3: idelay_state <= STATE_IDELAY_WAIT4;
                STATE_IDELAY_WAIT4: idelay_state <= STATE_IDELAY_IDLE;
                
                default: idelay_state <= STATE_IDELAY_IDLE;
            endcase
        end

    endgenerate
endmodule