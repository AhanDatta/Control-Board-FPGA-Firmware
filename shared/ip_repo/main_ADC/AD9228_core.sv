module AD9228_core #(
   parameter DATA_WIDTH = 12,
   parameter NUM_READS_BITS = 16;
)(
    input logic rstn,

    //adc inputs
    input logic din,
    input logic fco,
    input logic dco,

    output logic [DATA_WIDTH-1:0] des_data,
    output logic read_complete
);

    logic [DATA_WIDTH-1:0] des_data_incomplete;
    logic data_q1;
    logic data_q2;
    logic fco_prev;

    IDDRE1 #(
      .DDR_CLK_EDGE("OPPOSITE_EDGE"), // IDDRE1 mode (OPPOSITE_EDGE, SAME_EDGE, SAME_EDGE_PIPELINED)
      .IS_CB_INVERTED(1'b0),          // Optional inversion for CB
      .IS_C_INVERTED(1'b0)            // Optional inversion for C
   )
   IDDRE1_inst (
      .Q1(data_q1), // 1-bit output: Registered parallel output 1
      .Q2(data_q2), // 1-bit output: Registered parallel output 2
      .C(dco),   // 1-bit input: High-speed clock
      .CB(~dco), // 1-bit input: Inversion of High-speed clock C
      .D(din),   // 1-bit input: Serial Data Input
      .R(~rstn)    // 1-bit input: Active-High Async Reset
   );

   //main data collection state machine
   always_ff @(negedge rstn or posedge dco) begin
      if (!rstn) begin
         des_data_incomplete <= '0;
         des_data <= '0;
         read_complete <= 1'b0;
         fco_prev <= 1'b0;
      end
      else begin
         //handles the case of starting a new word
         if(fco & ~fco_prev) begin
            des_data <= des_data_incomplete;
            read_complete <= 1'b1;
         end
         else begin
            read_complete <= 1'b0;
         end

         des_data_incomplete <= {des_data_incomplete[DATA_WIDTH-3:0], data_q1, data_q2};
         fco_prev <= fco;
      end
   end   
endmodule