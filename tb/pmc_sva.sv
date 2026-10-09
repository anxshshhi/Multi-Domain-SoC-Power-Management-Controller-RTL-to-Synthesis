// ============================================================================
// Module: pmc_sva.sv
// Description: Procedural Assertions for Low-Power Sequence Rules (Icarus Compatible)
// ============================================================================

module pmc_sva (
    input wire clk,
    input wire rst_n,
    input wire cpu_ret_save,
    input wire cpu_iso_en,
    input wire cpu_rst_n,
    input wire cpu_pwr_sw_en
);

    reg prev_cpu_pwr_sw_en;
    reg prev_cpu_rst_n;

    always @(posedge clk) begin
        if (!rst_n) begin
            prev_cpu_pwr_sw_en <= 1'b1;
            prev_cpu_rst_n     <= 1'b0;
        end else begin
            prev_cpu_pwr_sw_en <= cpu_pwr_sw_en;
            prev_cpu_rst_n     <= cpu_rst_n;

            // Rule 1: Isolation MUST be asserted BEFORE power switch opens
            if (prev_cpu_pwr_sw_en && !cpu_pwr_sw_en) begin
                if (!cpu_iso_en) begin
                    $error("[SVA ERROR @ %0t ns] Power switch turned OFF before Isolation was enabled!", $time);
                end
            end

            // Rule 2: Power switch MUST turn ON BEFORE reset is released
            if (!prev_cpu_rst_n && cpu_rst_n) begin
                if (!cpu_pwr_sw_en) begin
                    $error("[SVA ERROR @ %0t ns] CPU Reset released while domain was still power-gated!", $time);
                end
            end

            // Rule 3: Isolation MUST stay asserted while power is shut off
            if (!cpu_pwr_sw_en) begin
                if (!cpu_iso_en) begin
                    $error("[SVA ERROR @ %0t ns] Isolation dropped while power rail was shut off!", $time);
                end
            end
        end
    end

endmodule