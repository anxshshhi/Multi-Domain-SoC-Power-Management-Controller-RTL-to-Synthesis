// ============================================================================
// Module: lp_cells_sky130.v
// Phase 4: SkyWater 130nm Level Shifter & Power Switch Explicit Primitives
// ============================================================================

// High-to-Low / Low-to-High Level Shifter
module sky130_ls_hl (
    input  wire A,   // Input signal in Domain 1
    output wire X    // Shifted signal in Domain 2
);
    // Behavioral representation for Yosys mapping & Gate simulation
    assign X = A;
endmodule

// Header Power Switch (PMOS Array for Power Gating)
module sky130_pwr_switch (
    input  wire sleep_en,  // Control signal (1 = Sleep/Off, 0 = Active)
    input  wire vdd_in,    // Continuous Rail
    output wire vdd_sw     // Switched Power Rail to PD_CPU
);
    assign vdd_sw = sleep_en ? 1'b0 : vdd_in;
endmodule
