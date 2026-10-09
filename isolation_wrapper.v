// ============================================================================
// Module: isolation_wrapper.v
// Description: Multi-bit Low-Power Output Isolation Cell
// Target Domain: Boundary between Power-Gated Domain and Always-On Domain
// ============================================================================

module isolation_wrapper #(
    parameter WIDTH = 32,
    parameter CLAMP_VALUE = 1'b0  // Clamps output to 0 (or 1) during isolation
)(
    input  wire [WIDTH-1:0] in_data,   // Signal coming from switchable power domain
    input  wire             iso_en,    // Isolation enable (1: active isolation)
    output wire [WIDTH-1:0] out_data   // Isolated output driven to rest of SoC
);

    // Structural clamp logic:
    // When iso_en == 1, outputs hold CLAMP_VALUE.
    // When iso_en == 0, outputs pass through in_data transparently.
    assign out_data = iso_en ? {WIDTH{CLAMP_VALUE}} : in_data;

endmodule