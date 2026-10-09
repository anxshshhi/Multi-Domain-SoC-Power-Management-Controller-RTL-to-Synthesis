// ============================================================================
// Module: pmc_apb_slave.v
// Description: APB3 Slave Bus Interface for Power Management Controller CSRs
// ============================================================================

module pmc_apb_slave #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    // APB3 Bus Interface
    input  wire                  PCLK,
    input  wire                  PRESETn,
    input  wire [ADDR_WIDTH-1:0] PADDR,
    input  wire                  PSEL,
    input  wire                  PENABLE,
    input  wire                  PWRITE,
    input  wire [DATA_WIDTH-1:0] PWDATA,
    output wire                  PREADY,
    output reg  [DATA_WIDTH-1:0] PRDATA,

    // Hardware Handshake Interfaces
    input  wire                  hw_sleep_req,
    input  wire                  wake_irq,

    // PMC Power Control Outputs to Domain Subsystem
    output wire                  cpu_ret_save,
    output wire                  cpu_ret_restore,
    output wire                  cpu_iso_en,
    output wire                  cpu_rst_n,
    output wire                  cpu_pwr_sw_en
);

    // Register Offsets
    localparam [ADDR_WIDTH-1:0] ADDR_PMC_CTRL   = 8'h00;
    localparam [ADDR_WIDTH-1:0] ADDR_PMC_STATUS = 8'h04;
    localparam [ADDR_WIDTH-1:0] ADDR_PMC_TIMING = 8'h08;

    // Internal Control Registers
    reg [DATA_WIDTH-1:0] reg_pmc_ctrl;
    reg [DATA_WIDTH-1:0] reg_pmc_timing;

    // Interconnect Wire Declarations
    wire       pmc_idle_out;
    wire       combined_sleep_req;

    // Combine Software CSR Sleep Request with Hardware Signal
    assign combined_sleep_req = hw_sleep_req | reg_pmc_ctrl[0];

    // Single-cycle APB Ready Response
    assign PREADY = 1'b1;

    // APB Write Register Decoding
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            reg_pmc_ctrl   <= {DATA_WIDTH{1'b0}};
            reg_pmc_timing <= 32'h0000_0004; // Default 4 cycles timeout
        end else if (PSEL && PENABLE && PWRITE) begin
            case (PADDR)
                ADDR_PMC_CTRL:   reg_pmc_ctrl   <= PWDATA;
                ADDR_PMC_TIMING: reg_pmc_timing <= PWDATA;
                default: ; // Unmapped registers ignored
            endcase
        end
    end

    // APB Read Data Decoding
    always @(*) begin
        PRDATA = {DATA_WIDTH{1'b0}};
        if (PSEL && !PWRITE) begin
            case (PADDR)
                ADDR_PMC_CTRL:   PRDATA = reg_pmc_ctrl;
                ADDR_PMC_STATUS: PRDATA = {27'd0, cpu_pwr_sw_en, 3'b000, pmc_idle_out};
                ADDR_PMC_TIMING: PRDATA = reg_pmc_timing;
                default:         PRDATA = {DATA_WIDTH{1'b0}};
            endcase
        end
    end

    // PMC Core FSM Instantiation
    pmc_core u_pmc_core (
        .clk_aon         (PCLK),
        .rst_n_aon       (PRESETn),
        .sleep_req       (combined_sleep_req),
        .wake_irq        (wake_irq),
        .pmc_idle        (pmc_idle_out),
        .cpu_ret_save    (cpu_ret_save),
        .cpu_ret_restore (cpu_ret_restore),
        .cpu_iso_en      (cpu_iso_en),
        .cpu_rst_n       (cpu_rst_n),
        .cpu_pwr_sw_en   (cpu_pwr_sw_en)
    );

endmodule
