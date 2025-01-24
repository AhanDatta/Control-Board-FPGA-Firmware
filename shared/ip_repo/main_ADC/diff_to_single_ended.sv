module diff_to_single_ended (
    input logic diff_p,
    input logic diff_n,
    output logic single_out
);

    IBUFDS #(
        .DIFF_TERM("TRUE"),     // Enable internal differential termination
        .IOSTANDARD("LVDS")     // Specify the I/O standard as LVDS
    ) ibufds_inst (
        .I(diff_p),             // Positive input
        .IB(diff_n),            // Negative input
        .O(single_out)          // Single-ended output
    );

endmodule