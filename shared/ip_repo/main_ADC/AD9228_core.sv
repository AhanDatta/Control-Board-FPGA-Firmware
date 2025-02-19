module AD9228_core #(
   parameter integer DATA_WIDTH = 12
)(
    input logic rstn,
    input logic clk, //sampling clock

    //adc inputs
    input logic din,
    input logic fco,
    input logic dco,

    output logic [DATA_WIDTH-1:0] des_data,
    output logic read_complete
);

    logic [DATA_WIDTH-1:0] des_data_incomplete;
    logic [1:0] data_q;
    logic [3:0] dco_counter;

   //Clocking in data on both clock edges
    IDDRE1 #(
      .DDR_CLK_EDGE("OPPOSITE_EDGE"), // IDDRE1 mode (OPPOSITE_EDGE, SAME_EDGE, SAME_EDGE_PIPELINED)
      .IS_CB_INVERTED(1'b1),          // Optional inversion for CB
      .IS_C_INVERTED(1'b0)            // Optional inversion for C
   )
   IDDRE1_inst (
      .Q1(data_q[0]), // 1-bit output: Registered parallel output 1
      .Q2(data_q[1]), // 1-bit output: Registered parallel output 2
      .C(dco),   // 1-bit input: High-speed clock
      .CB(dco), // 1-bit input: Inversion of High-speed clock C
      .D(din),   // 1-bit input: Serial Data Input
      .R(!rstn)    // 1-bit input: Active-High Async Reset
   );

   //combinatorically reads in data
   assign des_data = {des_data_incomplete[DATA_WIDTH-3:0], data_q};

   //latch for sending data to FIFO
   logic latch;
   logic latch_z;
   logic latch_z2;
   logic latch_pulse;
   assign latch_pulse = (latch_z2 == 1'b0) && (latch_z == 1'b1);
   assign read_complete = latch_pulse;

   //main data collection state machine
   always_ff @(negedge rstn or posedge dco) begin
      if (!rstn) begin
         des_data_incomplete <= '0;
         latch <= 1'b0;
         dco_counter <= '0;
      end
      else begin
         des_data_incomplete <= des_data;
         if (dco_counter == 'd5) begin
            dco_counter <= '0;
            latch <= 1'b1;
         end
         else begin
            dco_counter <= dco_counter + 1;
            latch <= 1'b0;
         end
      end
   end

   //clock domain crossing into clk 
   xpm_cdc_single #(
      .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
      .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .SRC_INPUT_REG(0)   // DECIMAL; 0=do not register input, 1=register input
   )
   xpm_cdc_single_inst (
      .dest_out(latch_z), // 1-bit output: src_in synchronized to the destination clock domain. This output is registered.
      .dest_clk(clk), // 1-bit input: Clock signal for the destination clock domain.
      .src_in(latch)      // 1-bit input: Input signal to be synchronized to dest_clk domain.
   );

   //setting latch_z2 as one clk cycle behind
   always_ff @(posedge clk or negedge rstn) begin
      if (!rstn) begin
         latch_z2 <= 1'b0;
      end
      else begin
         latch_z2 <= latch_z;
      end
   end
endmodule