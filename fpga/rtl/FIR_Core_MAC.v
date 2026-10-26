//****************************************************
// Company : Rochester Institute of Technology (RIT )
// Engineer : Ryan Hall (rah3587@rit.edu)
//
// Create Date : 10/14/26
// Design Name : FIR_Core_MAC
// Module Name : FIR_Core_MAC
// Project Name : FIR_Filter
// Target Devices : Basys3
//
// Description : Multiply-Accumulate architecture approach to FIR filter
//
// AI note     : Comments and code organization were done by Claude.
//
// Operation   : One output sample per input sample, computed serially with a single
//               multiplier. Because the filter is symmetric, only TAP_COUNT (59) of the
//               117 coefficients are stored, and each step pre-adds the two samples that
//               share a coefficient:  acc = sum( h[k] * (x[n-k] + x[n-116+k]) )
//               The centre tap (k = TAP_COUNT-1) has no partner, so it skips the pre-add.
//               The output is acc >> SHIFT, which undoes the coefficient scaling.
//
// FSM         : IDLE  - wait for sample_valid; the sample is written to the buffer
//               SWEEP - k steps through all 59 taps, one per clock
//               DRAIN - k held at the last tap while the pipeline empties
//
// Pipeline    : For a tap whose k is presented in cycle c:
//                 c   : k addresses sample_buffer and coef_rom
//                 c+1 : memory outputs (sample1, sample2, current_coeff)    flags *_mem
//                 c+2 : pre_sum register, coef_d register                   flags *_pre
//                 c+3 : product register                                    flags *_mult
//                 c+4 : accumulator (holds the full sum once last_tap_acc)  flags *_acc
//               The last_tap_* and valid_* flags travel down the pipeline with the data,
//               so each stage knows which tap it is holding. sample_out and out_valid
//               update on the edge that ends the last_tap_acc cycle.
//****************************************************
module FIR_Core_MAC #(
    parameter COEF_W = 16,       // coefficient width (bits)
    parameter SAMPLE_W = 16,     // input/output sample width (bits)
    parameter ACC_W = 39,        // accumulator width: 17 (pre-add) + COEF_W + ceil(log2(59))
    parameter SHIFT = 16,        // output right-shift (matches coefficient scaling)
    parameter TAP_COUNT = 59     // stored (folded) taps, centre tap last
)(
    input wire clk,
    input wire rst,                                   // synchronous reset
    input wire sample_valid,                          // one-cycle strobe: sample_in and ch_select are valid now
    input signed [SAMPLE_W-1:0] sample_in,            // new input sample
    input wire [1:0] ch_select,                       // coefficient set: 1, 2 or 3 (0 = zero output)
    output reg signed [SAMPLE_W-1:0] sample_out,      // filtered output sample
    output wire out_valid                             // one-cycle strobe: sample_out is valid
);

    //====================================================
    // Local parameters
    //====================================================
    localparam BUFF_SZ = TAP_COUNT*2 - 1;       // full filter length (117), sets sample_buffer depth
    localparam IDX_W  = $clog2(TAP_COUNT);      // bits to index a stored tap (0..58)
    localparam K_SZ = $clog2(BUFF_SZ);          // bits of k; sample_buffer accepts 0..116

    // State machine encoding
    localparam [1:0] S_IDLE = 2'd0,
                 S_SWEEP = 2'd1,
                 S_DRAIN = 2'd2;

    //====================================================
    // Signal declarations
    //====================================================

    // Control
    reg [1:0] state;
    reg [K_SZ-1:0] k;                           // tap index, drives both memories
    reg [1:0] ch_select_latched;                // ch_select captured when a sample arrives
    wire we;                                    // write the new sample into sample_buffer

    // Memory interface
    wire signed [COEF_W-1:0] current_coeff;     // coefficient for the tap addressed last cycle
    wire [IDX_W-1:0] coeff_index;               // k, truncated to coef_rom's address width
    wire signed [SAMPLE_W-1:0] sample1;         // x[n-k]
    wire signed [SAMPLE_W-1:0] sample2;         // x[n-116+k]

    // Pipeline flags: last_tap_* marks the centre tap (final tap of the sweep),
    // valid_* marks cycles holding real tap data. Suffix = stage the data is in.
    reg last_tap_mem;
    reg last_tap_pre;
    reg last_tap_mult;
    reg last_tap_acc;
    reg valid_mem;
    reg valid_pre;
    reg valid_mult;

    // Datapath registers
    reg signed [COEF_W-1:0] coef_d;             // current_coeff delayed one cycle to meet pre_sum
    reg signed [SAMPLE_W:0] pre_sum;            // 17 bits: one wider than a sample so the sum can't overflow
    reg signed [SAMPLE_W + COEF_W:0] product;   // 33 bits: 17-bit pre_sum x 16-bit coefficient
    reg signed [ACC_W-1:0] acc;                 // running sum; complete once last_tap_acc is high

    // Output
    reg out_valid_r;                            // registered copy of last_tap_acc, drives out_valid

    //====================================================
    // Control
    //====================================================

    // state switching process
    always @(posedge clk) begin
        if (rst)
            state <= S_IDLE;
        else begin
            case (state)
                S_IDLE:  if (sample_valid) state <= S_SWEEP;
                S_SWEEP: if (k == TAP_COUNT-1) state <= S_DRAIN;     // last tap addressed
                S_DRAIN: if (last_tap_acc) state <= S_IDLE;          // last tap has been accumulated
                default: state <= S_IDLE; // if undefined state
            endcase
        end
    end

    // k counting process
    // 0 in IDLE, steps 0..58 in SWEEP, then holds at 58 in DRAIN
    always @(posedge clk) begin
        case (state)
            S_IDLE:  k <= 0;
            S_SWEEP: if (k != TAP_COUNT-1) k <= k + 1;
            S_DRAIN: k <= TAP_COUNT-1;
            default: k <= 0; // if undefined state
        endcase
    end

    // Capture the channel once per sample so it can't change mid-sweep
    always @(posedge clk) begin
        if (state == S_IDLE && sample_valid)
            ch_select_latched <= ch_select;
    end

    assign coeff_index = k[IDX_W-1:0];
    assign we = sample_valid && (state == S_IDLE);   // new sample is written on the IDLE -> SWEEP edge

    //====================================================
    // Memories (both have one-cycle read latency)
    //====================================================

    // Instantiate coeff memory
    coef_rom #(
        .COEF_WIDTH (COEF_W),
        .TAP_COUNT  (TAP_COUNT)
    ) coef_rom_inst (
        .clk       (clk),
        .ch_select (ch_select_latched),
        .tap_index (coeff_index),
        .tap_out   (current_coeff)
    );

    // Instantiate sample buffer
    sample_buffer #(
        .BUFFER_COUNT(BUFF_SZ),
        .DATA_WIDTH(SAMPLE_W)
    ) sample_buff_inst (
        .clk(clk),
        .rst(rst),
        .we(we),
        .wd(sample_in),
        .k(k),
        .sample1(sample1),
        .sample2(sample2)
    );

    //====================================================
    // Pipeline flags
    //====================================================

    // last_tap_mem process: high in the cycle the memory outputs hold the centre tap
    always @(posedge clk) begin
        if (state == S_SWEEP && k == TAP_COUNT-1)
            last_tap_mem <= 1'b1;
        else
            last_tap_mem <= 1'b0;
    end

    // last_tap_* delay chain: one register per pipeline stage
    //last_tap_pre process
    always @(posedge clk) begin last_tap_pre <= last_tap_mem; end
    //last_tap_mult process
    always @(posedge clk) begin last_tap_mult <= last_tap_pre; end
    //last_tap_acc process
    always @(posedge clk) begin last_tap_acc <= last_tap_mult; end

    // valid_mem process: high for the 59 cycles the memory outputs hold real taps
    always @(posedge clk) begin
        if (state == S_SWEEP)
            valid_mem <= 1'b1;
        else
            valid_mem <= 1'b0;
    end

    // valid_* delay chain
    //valid_pre process
    always @(posedge clk) begin valid_pre <= valid_mem; end
    //valid_mult process
    always @(posedge clk) begin valid_mult <= valid_pre; end

    //====================================================
    // Datapath
    //====================================================

    // coef_d process: coefficient waits one cycle so it lines up with pre_sum at the multiplier
    always @(posedge clk) begin coef_d <= current_coeff; end

    // pre_sum process
    always @(posedge clk) begin
        if (last_tap_mem)
            pre_sum <= sample1;              // centre tap: both samples are the same, don't add
        else
            pre_sum <= sample1 + sample2;
    end

    // product process
    always @(posedge clk) begin
        product <= pre_sum * coef_d;
    end

    // acc process: cleared in IDLE, adds a product only on cycles holding a real tap,
    // and holds the finished sum through DRAIN
    always @(posedge clk) begin
        if (state == S_IDLE)
            acc <= {ACC_W{1'b0}};
        else if (valid_mult)
            acc <= acc + product;
        else
            acc <= acc;
    end

    //====================================================
    // Output
    //====================================================

    // sample_out process: keep the integer part of the sum (acc >> SHIFT) once it is complete
    always @(posedge clk) begin
        if (last_tap_acc)
            sample_out <= acc[SHIFT+SAMPLE_W-1 : SHIFT];
    end

    // out_valid_r process: one-cycle pulse, same cycle sample_out shows the new value
    always @(posedge clk) begin
        out_valid_r <= last_tap_acc;
    end
    assign out_valid = out_valid_r;

endmodule