module process_vtune #(
    parameter ADC_WIDTH = 16,

) (
    input logic[ADC_WIDTH-1] pre_vtune,
    output logic [ADC_WIDTH-1] post_vtune
);

    assign post_vtune = pre_vtune;

endmodule