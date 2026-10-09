# Multi-Domain-SoC-Power-Management-Controller-RTL-to-Synthesis
an FSM-based SoC power management controller in Verilog (RTL design) that sequences shutdown and wake-up across multiple power domains, with control logic for power gating, output isolation, and state retention, plus an APB register interface for software-driven control.


## Features

- 🔁 **FSM-based sequencing** - power-down and power-up for multiple power domains
- 🔌 **Power gating control** - switches domains on and off
- 🛡️ **Output isolation control** - stops unknown values propagating out of a powered-down domain
- 💾 **State retention control** - saves and restores domain state across power cycles
- 🧩 **APB slave register interface** - software-driven power-state control and status readback
- 🧪 **Testbench-based verification** - simulation with waveform-level debugging
- 📊 **Synthesis and static timing analysis** - quantifies area and timing overhead

## Tech Stack

- 🧠 **Verilog** - the language the RTL is written in (FSM, APB interface, control logic)
- 🧪 **Icarus Verilog** - compiles and simulates the design and testbenches
- 📈 **GTKWave** - waveform viewer, used for debugging FSM states and signal timing
- ⚙️ **Yosys** - synthesizes the RTL into a gate-level netlist and reports cell count and area
- ⏱️ **OpenSTA** - static timing analysis on the netlist: critical path and slack
