module single_ended_to_diff (
    input logic single_in,
    output logic diff_p,
    output logic diff_n
);

    OBUFDS #(
        .IOSTANDARD("LVDS_25"), // Specify the I/O standard
        .SLEW("FAST")           // Specify the output slew rate
    ) obufds_inst (
        .I(single_in),          // Single-ended input
        .O(diff_p),             // Positive output
        .OB(diff_n)            // Negative output
    );

endmodule