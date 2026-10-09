// ============================================================================
// Module: pmc_core.v
// Description: Multi-Domain SoC Power Management Controller (PMC) - Verilog-2001
// Target Domain: Manages sequencing for Power Domain PD_CPU
// ============================================================================

module pmc_core #(
    parameter TIMEOUT_CYCLES = 4  // Delay cycles for power switch/rail settling
)(
    input  wire clk_aon,          // Always-On Clock
    input  wire rst_n_aon,        // Always-On Reset (Active Low)

    // Handshake Interfaces (from System / CPU Core)
    input  wire sleep_req,        // Sleep request (e.g., from WFI logic)
    input  wire wake_irq,         // Wakeup interrupt signal
    output reg  pmc_idle,         // PMC idle / sleep state indicator

    // Power Domain Control Sideband Signals
    output reg  cpu_ret_save,     // 1: Save state to SRPG registers
    output reg  cpu_ret_restore,  // 1: Restore state from SRPG registers
    output reg  cpu_iso_en,       // 1: Clamp outputs to prevent X-prop
    output reg  cpu_rst_n,        // 0: Assert reset to domain
    output reg  cpu_pwr_sw_en     // 1: Turn ON power switch, 0: OFF
);

    // FSM State Definitions using Parameters
    parameter ST_ACTIVE      = 4'b0000;
    parameter ST_RET_SAVE    = 4'b0001;
    parameter ST_ISO_ENABLE  = 4'b0011;
    parameter ST_RST_ASSERT  = 4'b0010;
    parameter ST_PWR_OFF     = 4'b0110;
    parameter ST_SLEEP       = 4'b0111;
    parameter ST_PWR_ON      = 4'b0101;
    parameter ST_ISO_DISABLE = 4'b0100;
    parameter ST_RET_RESTORE = 4'b1100;
    parameter ST_RST_RELEASE = 4'b1000;

    reg [3:0] current_state, next_state;

    // Internal Counter for Power Rail Ramp Delays
    reg [3:0] timer;
    reg       timer_clear;

    // ------------------------------------------------------------------------
    // 1. FSM Sequential State Register & Delay Counter
    // ------------------------------------------------------------------------
    always @(posedge clk_aon or negedge rst_n_aon) begin
        if (!rst_n_aon) begin
            current_state <= ST_ACTIVE;
            timer         <= 4'b0000;
        end else begin
            current_state <= next_state;
            if (timer_clear)
                timer <= 4'b0000;
            else
                timer <= timer + 1'b1;
        end
    end

    // ------------------------------------------------------------------------
    // 2. FSM Next-State Logic
    // ------------------------------------------------------------------------
    always @(*) begin
        next_state  = current_state;
        timer_clear = 1'b0;

        case (current_state)
            ST_ACTIVE: begin
                if (sleep_req) begin
                    next_state  = ST_RET_SAVE;
                    timer_clear = 1'b1;
                end
            end

            ST_RET_SAVE: begin
                if (timer == TIMEOUT_CYCLES) begin
                    next_state  = ST_ISO_ENABLE;
                    timer_clear = 1'b1;
                end
            end

            ST_ISO_ENABLE: begin
                if (timer == TIMEOUT_CYCLES) begin
                    next_state  = ST_RST_ASSERT;
                    timer_clear = 1'b1;
                end
            end

            ST_RST_ASSERT: begin
                if (timer == TIMEOUT_CYCLES) begin
                    next_state  = ST_PWR_OFF;
                    timer_clear = 1'b1;
                end
            end

            ST_PWR_OFF: begin
                if (timer == TIMEOUT_CYCLES) begin
                    next_state  = ST_SLEEP;
                    timer_clear = 1'b1;
                end
            end

            ST_SLEEP: begin
                if (wake_irq) begin
                    next_state  = ST_PWR_ON;
                    timer_clear = 1'b1;
                end
            end

            ST_PWR_ON: begin
                if (timer == TIMEOUT_CYCLES) begin
                    next_state  = ST_ISO_DISABLE;
                    timer_clear = 1'b1;
                end
            end

            ST_ISO_DISABLE: begin
                if (timer == TIMEOUT_CYCLES) begin
                    next_state  = ST_RET_RESTORE;
                    timer_clear = 1'b1;
                end
            end

            ST_RET_RESTORE: begin
                if (timer == TIMEOUT_CYCLES) begin
                    next_state  = ST_RST_RELEASE;
                    timer_clear = 1'b1;
                end
            end

            ST_RST_RELEASE: begin
                if (timer == TIMEOUT_CYCLES) begin
                    next_state  = ST_ACTIVE;
                    timer_clear = 1'b1;
                end
            end

            default: next_state = ST_ACTIVE;
        endcase
    end

    // ------------------------------------------------------------------------
    // 3. Output Assignment Logic
    // ------------------------------------------------------------------------
    always @(*) begin
        // Safe Defaults
        cpu_ret_save    = 1'b0;
        cpu_ret_restore = 1'b0;
        cpu_iso_en      = 1'b0;
        cpu_rst_n       = 1'b1;
        cpu_pwr_sw_en   = 1'b1;
        pmc_idle        = 1'b0;

        case (current_state)
            ST_ACTIVE: begin
                // All active defaults
            end

            ST_RET_SAVE: begin
                cpu_ret_save = 1'b1;
            end

            ST_ISO_ENABLE: begin
                cpu_iso_en = 1'b1;
            end

            ST_RST_ASSERT: begin
                cpu_iso_en = 1'b1;
                cpu_rst_n  = 1'b0;
            end

            ST_PWR_OFF: begin
                cpu_iso_en    = 1'b1;
                cpu_rst_n     = 1'b0;
                cpu_pwr_sw_en = 1'b0;
            end

            ST_SLEEP: begin
                cpu_iso_en    = 1'b1;
                cpu_rst_n     = 1'b0;
                cpu_pwr_sw_en = 1'b0;
                pmc_idle      = 1'b1;
            end

            ST_PWR_ON: begin
                cpu_iso_en    = 1'b1;
                cpu_rst_n     = 1'b0;
                cpu_pwr_sw_en = 1'b1;
            end

            ST_ISO_DISABLE: begin
                cpu_iso_en  = 1'b0;
                cpu_rst_n   = 1'b0;
            end

            ST_RET_RESTORE: begin
                cpu_ret_restore = 1'b1;
                cpu_rst_n       = 1'b0;
            end

            ST_RST_RELEASE: begin
                cpu_rst_n = 1'b1;
            end
        endcase
    end

endmodule