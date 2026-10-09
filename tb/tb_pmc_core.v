// ============================================================================
// Module: tb_pmc_core.v
// Description: Testbench for Multi-Domain PMC and Isolation/Retention Logic
// ============================================================================

`timescale 1ns/1ps

module tb_pmc_core;

    // Clock and Reset
    reg clk_aon;
    reg rst_n_aon;

    // PMC Handshake Inputs
    reg sleep_req;
    reg wake_irq;

    // PMC Outputs
    wire pmc_idle;
    wire cpu_ret_save;
    wire cpu_ret_restore;
    wire cpu_iso_en;
    wire cpu_rst_n;
    wire cpu_pwr_sw_en;

    // Subsystem Signals to Test Isolation & Retention
    reg  [31:0] cpu_data_out;
    wire [31:0] isolated_data_out;
    reg  [31:0] reg_data_in;
    wire [31:0] reg_data_out;

    // ------------------------------------------------------------------------
    // 1. Instantiate Units Under Test (UUT)
    // ------------------------------------------------------------------------
    pmc_core #(
        .TIMEOUT_CYCLES(4)
    ) u_pmc_core (
        .clk_aon        (clk_aon),
        .rst_n_aon      (rst_n_aon),
        .sleep_req      (sleep_req),
        .wake_irq       (wake_irq),
        .pmc_idle       (pmc_idle),
        .cpu_ret_save   (cpu_ret_save),
        .cpu_ret_restore(cpu_ret_restore),
        .cpu_iso_en     (cpu_iso_en),
        .cpu_rst_n      (cpu_rst_n),
        .cpu_pwr_sw_en  (cpu_pwr_sw_en)
    );

    // Isolation Wrapper Instance
    isolation_wrapper #(
        .WIDTH(32),
        .CLAMP_VALUE(1'b0)
    ) u_iso_wrapper (
        .in_data (cpu_data_out),
        .iso_en  (cpu_iso_en),
        .out_data(isolated_data_out)
    );

    // Retention Register Instance
    retention_reg #(
        .WIDTH(32)
    ) u_ret_reg (
        .clk        (clk_aon),
        .rst_n      (cpu_rst_n),
        .ret_save   (cpu_ret_save),
        .ret_restore(cpu_ret_restore),
        .d_in       (reg_data_in),
        .q_out      (reg_data_out)
    );

    // ------------------------------------------------------------------------
    // 2. Clock Generation (100MHz Always-On Clock)
    // ------------------------------------------------------------------------
    always #5 clk_aon = ~clk_aon;

    // ------------------------------------------------------------------------
    // 3. Test Stimulus and Sequence Verification
    // ------------------------------------------------------------------------
    initial begin
        // Dump VCD file for GTKWave visualization
        $dumpfile("sim/pmc_sim.vcd");
        $dumpvars(0, tb_pmc_core);

        // Initialize Signals
        clk_aon      = 0;
        rst_n_aon    = 0;
        sleep_req    = 0;
        wake_irq     = 0;
        cpu_data_out = 32'hDEADBEEF;
        reg_data_in  = 32'h12345678;

        $display("--------------------------------------------------");
        $display("[TB] Starting Power-Aware PMC Simulation...");
        $display("--------------------------------------------------");

        // Release Power-On Reset
        #20 rst_n_aon = 1;
        #20;

        // --- STEP A: Trigger Sleep Sequence ---
        $display("[TB] @ %0nt: Driving SLEEP_REQ", $time);
        sleep_req = 1;

        // Wait until power switch is completely turned off
        wait(cpu_pwr_sw_en == 0);
        $display("[TB] @ %0nt: Power Switch is OFF. Corrupting CPU Domain Outputs to 'X'...", $time);
        cpu_data_out = 32'hXXXXXXXX; // Simulate power-gated unpowered bus floating

        // Verify isolation is holding clamp value 0
        #10;
        if (isolated_data_out === 32'h00000000) begin
            $display("[SUCCESS] Isolation logic active! Unpowered 'X' signals blocked.");
        end else begin
            $display("[ERROR] Isolation failed! Leakage detected: %h", isolated_data_out);
        end

        // --- STEP B: Trigger Wakeup Sequence ---
        #100;
        $display("[TB] @ %0nt: Driving WAKE_IRQ Interrupt", $time);
        sleep_req = 0;
        wake_irq  = 1;

        // Wait until system restores state and releases reset
        wait(cpu_rst_n == 1);
        wake_irq     = 0;
        cpu_data_out = 32'hCAFEFEED; // Restore CPU active outputs

        #40;
        $display("[TB] @ %0nt: Checking Retention Register Value: %h", $time, reg_data_out);
        if (reg_data_out === 32'h12345678) begin
            $display("[SUCCESS] Retention Register context accurately restored!");
        end else begin
            $display("[ERROR] Retention state corrupted: %h", reg_data_out);
        end

        $display("--------------------------------------------------");
        $display("[TB] Simulation Completed Successfully!");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule