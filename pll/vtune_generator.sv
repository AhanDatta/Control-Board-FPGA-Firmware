module vtune_generator #(
    parameter DAC_WIDTH = 16,
    parameter VTUNE_INCREASE_INCREMENT = 16,
    parameter VTUNE_DECREASE_INCREMENT = 1) (
    input logic phase_signal,
    input logic sampling_clk,
    input logic rstn,
    output logic [DAC_WIDTH-1:0] vtune 
);

    initial begin
        vtune = 0;
    end

    always_ff @(posedge sampling_clk or negedge rstn) begin
        if (!rstn) begin
            vtune <= 0;
        end
        else begin
            if (phase_signal) begin
                vtune <= vtune + VTUNE_INCREASE_INCREMENT;
            end
            else begin
                vtune <= vtune - VTUNE_DECREASE_INCREMENT;
            end
        end
    end
endmodule