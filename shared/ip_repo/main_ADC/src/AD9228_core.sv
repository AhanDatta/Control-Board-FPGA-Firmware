module AD9228_core #(
   parameter integer DATA_WIDTH = 12
)(
    input logic rstn,
    input logic clk, //sampling clock

    //adc inputs
    input logic din,
    input logic fco,
    input logic dco,

    output logic [DATA_WIDTH-1:0] des_data
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
      .Q1(data_q[1]), // 1-bit output: Registered parallel output 1
      .Q2(data_q[0]), // 1-bit output: Registered parallel output 2
      .C(dco),   // 1-bit input: High-speed clock
      .CB(dco), // 1-bit input: Inversion of High-speed clock C
      .D(din),   // 1-bit input: Serial Data Input
      .R(!rstn)    // 1-bit input: Active-High Async Reset
   );

   //main data collection state machine
   always_ff @(negedge rstn or posedge dco) begin
      if (!rstn) begin
         des_data_incomplete <= '0;
         des_data <= '0;
         dco_counter <= '0;
      end
      else begin
         des_data_incomplete <= {des_data_incomplete[DATA_WIDTH-3:0], data_q};
         if (dco_counter == 'd1) begin
            des_data <= des_data_incomplete;
            dco_counter <= dco_counter + 1;
         end
         else if (dco_counter == 'd5) begin
            des_data <= des_data;
            dco_counter <= '0;
         end
         else begin
            des_data <= des_data;
            dco_counter <= dco_counter + 1;
         end
      end
   end
endmodule