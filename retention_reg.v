// ============================================================================
// Module: retention_reg.v
// Description: State Retention Power Gated (SRPG) Register Module
// Target Domain: Switchable Power Domain (PD_CPU)
// ============================================================================

module retention_reg #(
    parameter WIDTH = 32
)(
    input  wire             clk,           // Functional clock
    input  wire             rst_n,         // Functional reset
    input  wire             ret_save,      // Save active state into balloon latch
    input  wire             ret_restore,   // Restore state from balloon latch
    input  wire [WIDTH-1:0] d_in,          // Data input
    output reg  [WIDTH-1:0] q_out          // Data output
);

    // Internal "Balloon Latch" powered by VDD_AO (Always-On Supply)
    reg [WIDTH-1:0] shadow_latch;

    // 1. Normal Functional Register Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_out <= {WIDTH{1'b0}};
        end else begin
            q_out <= d_in;
        end
    end

    // 2. SRPG Shadow Latch Operations
    // - On ret_save: Snapshot current active state into shadow storage
    // - On ret_restore: Force shadow storage back into active register
    always @(*) begin
        if (ret_save) begin
            shadow_latch = q_out;
        end
    end

    always @(*) begin
        if (ret_restore) begin
            q_out = shadow_latch;
        end
    end

endmodule
