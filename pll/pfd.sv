module d_ff (
    input logic d,
    input logic clk,
    input logic rstn,
    output logic q
);
    initial begin
        q = 0;
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            q <= 0;
        end
        else begin 
            q <= d;
        end
    end 
endmodule

module pfd (
    input logic ref_clk,
    input logic chip_clk,
    output logic phase_signal
);
    logic fb_sig;
    logic ref_clk_out;
    logic chip_clk_out;

    assign fb_sig = !(ref_clk_out && chip_clk_out);
    d_ff ref_ff(.d (1), .clk (ref_clk), .rstn (fb_sig), .q (ref_clk_out));
    d_ff chip_ff(.d (1), .clk (chip_clk), .rstn (fb_sig), .q (chip_clk_out));

    assign phase_signal = ref_clk_out ^ chip_clk_out;
endmodule