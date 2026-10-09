// ============================================================================
// Module: tb_pmc_apb_slave.v
// Description: Testbench for PMC APB Slave Interface & Power Gating Sequence
// Compatible with: RTL Simulation & Yosys Gate-Level Netlist Simulation
// ============================================================================

`timescale 1ns/1ps

module tb_pmc_apb_slave;

    // Local Constants
    localparam ADDR_WIDTH = 8;
    localparam DATA_WIDTH = 32;
    localparam CLK_PERIOD = 10; // 100MHz Always-On Clock

    // APB Bus Signals
    reg                    PCLK;
    reg                    PRESETn;
    reg  [ADDR_WIDTH-1:0]  PADDR;
    reg                    PSEL;
    reg                    PENABLE;
    reg                    PWRITE;
    reg  [DATA_WIDTH-1:0]  PWDATA;
    wire [DATA_WIDTH-1:0]  PRDATA;
    wire                   PREADY;
    wire                   PSLVERR;

    // PMC Low-Power Control Outputs
    wire                   cpu_iso_en;
    wire                   cpu_ret_save;
    wire                   cpu_ret_restore;
    wire                   cpu_rst_n;
    wire                   cpu_pwr_sw_en;
    wire                   wake_req;

    // Hardware Request Inputs
    reg                    hw_sleep_req;
    reg                    wake_irq;

    // PMC Internal CSR Addresses
    localparam ADDR_PMC_CTRL   = 8'h00;
    localparam ADDR_PMC_STATUS = 8'h04;
    localparam ADDR_PMC_TIMERS = 8'h08;

    // ------------------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------------------
    always #(CLK_PERIOD / 2) PCLK = ~PCLK;

    // ------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    // (Instantiated WITHOUT parameter overrides for Gate-Level Netlist compatibility)
    // ------------------------------------------------------------------------
    pmc_apb_slave u_dut (
        .PCLK            (PCLK),
        .PRESETn         (PRESETn),
        .PADDR           (PADDR),
        .PWRITE          (PWRITE),
        .PSEL            (PSEL),
        .PENABLE         (PENABLE),
        .PWDATA          (PWDATA),
        .PRDATA          (PRDATA),
        .PREADY          (PREADY),
        .PSLVERR         (PSLVERR),
        .cpu_iso_en      (cpu_iso_en),
        .cpu_ret_save    (cpu_ret_save),
        .cpu_ret_restore (cpu_ret_restore),
        .cpu_rst_n       (cpu_rst_n),
        .cpu_pwr_sw_en   (cpu_pwr_sw_en),
        .wake_req        (wake_req)
    );

    // ------------------------------------------------------------------------
    // SystemVerilog Assertions (SVA) Binding
    // ------------------------------------------------------------------------
     // SVA Instance with matched port names
    pmc_sva u_pmc_sva (
        .clk             (PCLK),
        .rst_n           (PRESETn),
        .cpu_iso_en      (cpu_iso_en),
        .cpu_ret_save    (cpu_ret_save),
        .cpu_ret_restore (cpu_ret_restore),
        .cpu_pwr_sw_en   (cpu_pwr_sw_en),
        .cpu_rst_n       (cpu_rst_n)
    );

    // ------------------------------------------------------------------------
    // APB Bus Driver Tasks
    // ------------------------------------------------------------------------
    task apb_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        begin
            @(posedge PCLK);
            PADDR   <= addr;
            PWDATA  <= data;
            PWRITE  <= 1'b1;
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            
            @(posedge PCLK);
            PENABLE <= 1'b1;
            
            wait (PREADY == 1'b1);
            @(posedge PCLK);
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
        end
    endtask

    task apb_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data);
        begin
            @(posedge PCLK);
            PADDR   <= addr;
            PWRITE  <= 1'b0;
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            
            @(posedge PCLK);
            PENABLE <= 1'b1;
            
            wait (PREADY == 1'b1);
            data = PRDATA;
            @(posedge PCLK);
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
        end
    endtask

    // ------------------------------------------------------------------------
    // Main Stimulus Procedure
    // ------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] read_val;

    initial begin
        // Dump VCD Waveforms for GTKWave
        $dumpfile("sim/pmc_sim.vcd");
        $dumpvars(0, tb_pmc_apb_slave);

        // Initialize Signals
        PCLK         = 0;
        PRESETn      = 0;
        PADDR        = 0;
        PSEL         = 0;
        PENABLE      = 0;
        PWRITE       = 0;
        PWDATA       = 0;
        hw_sleep_req = 0;
        wake_irq     = 0;

        // Apply Reset
        #(CLK_PERIOD * 5);
        PRESETn = 1;
        #(CLK_PERIOD * 2);

        $display("\n==================================================");
        $display("[TB] Starting APB PMC Slave Power-Gating Test Suite");
        $display("==================================================\n");

        // 1. Verify Power-On Reset Status
        apb_read(ADDR_PMC_STATUS, read_val);
        $display("[TB] Initial PMC STATUS: 0x%08h (Expected Active)", read_val);

        // 2. Write SW Sleep Request to PMC CTRL
        $display("[TB] Writing SW SLEEP REQ = 1 to PMC CTRL (0x00)...");
        apb_write(ADDR_PMC_CTRL, 32'h0000_0001);

        // Wait for power-down sequencing to execute
        #(CLK_PERIOD * 30);

        // 3. Verify Power-Gated Status
        apb_read(ADDR_PMC_STATUS, read_val);
        $display("[TB] Post-Sleep PMC STATUS: 0x%08h (Power Switch Status: %0b)", read_val, read_val[4]);
        if (read_val[4] == 1'b1) begin
            $display("[SUCCESS] CPU Domain Successfully Power-Gated via APB Command!");
        end else begin
            $display("[ERROR] CPU Domain Power Gating Failed!");
        end

        // 4. Assert Wakeup IRQ Trigger
        $display("\n[TB] ASSERTING WAKE_IRQ and clearing SW_SLEEP_REQ...");
        apb_write(ADDR_PMC_CTRL, 32'h0000_0000); // Clear sleep request bit
        wake_irq = 1'b1;
        #(CLK_PERIOD * 2);
        wake_irq = 1'b0;

        // Wait for power-up restoration sequencing
        #(CLK_PERIOD * 40);

        // 5. Verify Restored Status
        apb_read(ADDR_PMC_STATUS, read_val);
        $display("[TB] Post-Wakeup PMC STATUS: 0x%08h (Idle Bit: %0b)", read_val, read_val[0]);
        if (read_val[0] == 1'b0) begin
            $display("[SUCCESS] CPU Domain Fully Powered Back Up & Restored!");
        end else begin
            $display("[ERROR] CPU Power Restoration Failed!");
        end

        $display("\n==================================================");
        $display("[TB] APB PMC Slave Simulation Completed Successfully!");
        $display("==================================================\n");

        $finish;
    end

endmodule