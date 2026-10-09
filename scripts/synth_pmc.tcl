# ============================================================================
# Script: scripts/synth_pmc.tcl
# Description: RTL & Low-Power Synthesis Script (Cadence Genus / Synopsys DC)
# ============================================================================

# 1. Target Library & Search Paths
set_db init_lib_search_path {./libs}
set_db hdl_search_path       {./rtl ./upf}

# Load Liberty (.lib) Files with Power Models
read_libs stdcell_hd_tt_1v0_25c.lib

# 2. Read HDL Sources
read_hdl -language sv {
    rtl/pmc_core.v
    rtl/pmc_apb_slave.v
    rtl/isolation_wrapper.v
    rtl/retention_reg.v
}

# 3. Elaborate Top Design
elaborate pmc_apb_slave

# 4. Read Low-Power Intent (UPF)
read_upf upf/soc_power_intent.upf
apply_upf

# 5. Apply Basic Timing Constraints
create_clock -name PCLK -period 10.0 [get_ports PCLK]
set_input_delay  2.0 -clock PCLK [all_inputs]
set_output_delay 2.0 -clock PCLK [all_outputs]

# 6. Low-Power Synthesis & Insertion of Power Management Cells
set_db lp_insert_clock_gating true
syn_generic
syn_map
syn_opt

# 7. Write Out Reports & Netlist
write_hdl > netlist/pmc_apb_slave_gate.v
write_upf netlist/pmc_apb_slave_gate.upf
report_power > reports/power_report.txt
report_timing > reports/timing_report.txt
report_gates  > reports/gate_report.txt

puts "[SYNTHESIS COMPLETE] Gate-level netlist and updated UPF exported."
