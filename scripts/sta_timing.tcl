# 1. Read Netlist & Elaborate Top Module
read_verilog netlist/pmc_mapped.v
hierarchy -top pmc_apb_slave

# 2. Lower to Primitive Gates
proc; opt
simplemap
techmap
opt

# 3. Analyze Setup (Max Path Delay across Logic Levels)
echo SETUP ANALYSIS (MAX DELAY PATHS)
sta -dff

# 4. Analyze Hold (Min Path Delay / Shortest Paths)
echo HOLD ANALYSIS (MIN DELAY PATHS)
sta -dff