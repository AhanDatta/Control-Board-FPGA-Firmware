module AD9228_core #(
   parameter logic DIN_INVERTED = 0,
   parameter logic DCO_INVERTED = 0,
   parameter logic FCO_INVERTED = 0,
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
   logic din_prime;

   assign din_prime = DIN_INVERTED ? ~din : din;

   generate
      if (DCO_INVERTED) begin : gen_inverted_dco
         IDDRE1 #(
            .DDR_CLK_EDGE("SAME_EDGE"),
            .IS_CB_INVERTED(1'b0),
            .IS_C_INVERTED(1'b1)
         ) IDDRE1_inst (
            .Q1(data_q[1]),
            .Q2(data_q[0]),
            .C(dco),
            .CB(dco),
            .D(din_prime),
            .R(!rstn)
         );
      end
      else begin : gen_regular_dco
         IDDRE1 #(
            .DDR_CLK_EDGE("OPPOSITE_EDGE"),
            .IS_CB_INVERTED(1'b1),
            .IS_C_INVERTED(1'b0)
         ) IDDRE1_inst (
            .Q1(data_q[1]),
            .Q2(data_q[0]),
            .C(dco),
            .CB(dco),
            .D(din_prime),
            .R(!rstn)
         );
      end
   endgenerate

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