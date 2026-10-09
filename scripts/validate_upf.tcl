# ============================================================================
# Script: scripts/validate_upf.tcl
# Description: Static UPF Rule & Power Intent Verification Script
# ============================================================================

puts "--------------------------------------------------"
puts "[LP-VERIF] Starting UPF Low-Power Static Checks..."
puts "--------------------------------------------------"

# 1. Set HDL & UPF Search Paths
set_db hdl_search_path {./rtl ./upf}

# 2. Read HDL Top Files
read_hdl -language sv {
    rtl/pmc_core.v
    rtl/pmc_apb_slave.v
    rtl/isolation_wrapper.v
    rtl/retention_reg.v
}

# 3. Elaborate Design
elaborate pmc_apb_slave

# 4. Load & Parse Power Intent (UPF)
puts "[LP-VERIF] Loading upf/soc_power_intent.upf..."
read_upf upf/soc_power_intent.upf
apply_upf

# 5. Run Low-Power Rule Checks
# - Verifies un-isolated domain crossings
# - Verifies power switch control signal connectivity
# - Checks supply net / power state table (PST) completeness
check_power_intent -detailed -out_file reports/upf_validation_report.rpt

puts "--------------------------------------------------"
puts "[LP-VERIF] UPF Validation Complete! Check reports/upf_validation_report.rpt"
puts "--------------------------------------------------"