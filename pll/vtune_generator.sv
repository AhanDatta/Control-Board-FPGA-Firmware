module vtune_generator #(
    parameter DAC_WIDTH = 16,
    parameter FINE_TUNE_BITS = 4,
    parameter VTUNE_INCREASE_INCREMENT = 16,
    parameter VTUNE_DECREASE_INCREMENT = 1) (
    input logic phase_signal,
    input logic sampling_clk,
    input logic rstn,
    output logic [DAC_WIDTH-1:0] vtune 
);

    logic [DAC_WIDTH+FINE_TUNE_BITS-1:0] fine_vtune;
    initial begin
        fine_vtune = 0;
    end

    always_ff @(posedge sampling_clk or negedge rstn) begin
        if (!rstn) begin
            fine_vtune <= 0;
        end
        else begin
            if (phase_signal) begin
                fine_vtune <= fine_vtune + VTUNE_INCREASE_INCREMENT;
            end
            else begin
                fine_vtune <= fine_vtune - VTUNE_DECREASE_INCREMENT;
            end
        end
    end

    assign vtune = fine_vtune[DAC_WIDTH+FINE_TUNE_BITS-1 -:DAC_WIDTH];
endmodule