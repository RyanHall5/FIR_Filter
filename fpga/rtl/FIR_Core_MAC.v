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
// Description : Multiply-Accumulate architecture approach to FIR filter, with LANES
//               multiply-accumulate lanes working in parallel (LANES = 1 is the serial MAC)
//
// AI note     : Comments and code organization were done by Claude. The per-lane
//               datapath and lane-sum stage were added by Claude (Anthropic).
//
// Operation   : One output sample per input sample. Because the filter is symmetric, only
//               TAP_COUNT (59) of the 117 coefficients are stored, and each lane pre-adds
//               the two samples that share a coefficient:
//                   acc = sum( h[t] * (x[n-t] + x[n-116+t]) )
//               The sweep takes STEPS = ceil(TAP_COUNT/LANES) steps. On step k, lane i
//               works on tap t = k*LANES + i. Taps past TAP_COUNT-1 are padding: their
//               coefficient reads as 0, so they add nothing. The centre tap (t =
//               TAP_COUNT-1) has no partner, so its lane skips the pre-add. The lane
//               products are summed every clock into one accumulator. The output is
//               acc >> SHIFT, which undoes the coefficient scaling.
//
// FSM         : IDLE  - wait for sample_valid; the sample is written to the buffer
//               SWEEP - k steps through STEPS steps, one per clock (LANES taps each)
//               DRAIN - k held at the last step while the pipeline empties
//
// Pipeline    : For a step whose k is presented in cycle c:
//                 c   : k addresses sample_buffer and coef_rom
//                 c+1 : memory outputs (sample1, sample2, coefficients)     flags *_mem
//                 c+2 : pre_sum register, coef_d register (per lane)        flags *_pre
//                 c+3 : product register (per lane)                         flags *_mult
//                 c+4 : accumulator adds the sum of all lane products;
//                       it holds the full sum once last_tap_acc is high     flags *_acc
//               The last_tap_* and valid_* flags travel down the pipeline with the data,
//               so each stage knows which step it is holding. sample_out and out_valid
//               update on the edge that ends the last_tap_acc cycle.
//****************************************************
module FIR_Core_MAC #(
    parameter COEF_W = 16,       // coefficient width (bits)
    parameter SAMPLE_W = 16,     // input/output sample width (bits)
    parameter ACC_W = 39,        // accumulator width: 17 (pre-add) + COEF_W + ceil(log2(59))
    parameter SHIFT = 16,        // output right-shift (matches coefficient scaling)
    parameter TAP_COUNT = 59,    // stored (folded) taps, centre tap last
    parameter LANES = 1          // taps processed per clock (1 = serial MAC)
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
    localparam STEPS = (TAP_COUNT + LANES - 1) / LANES; // clocks in a sweep: ceil(TAP_COUNT/LANES)
    localparam PROD_W = SAMPLE_W + COEF_W + 1;  // 33 bits: 17-bit pre_sum x 16-bit coefficient

    // State machine encoding
    localparam [1:0] S_IDLE = 2'd0,
                 S_SWEEP = 2'd1,
                 S_DRAIN = 2'd2;

    //====================================================
    // Signal declarations
    //====================================================

    // Control
    reg [1:0] state;
    reg [K_SZ-1:0] k;                           // step index (0..STEPS-1), drives both memories
    reg [1:0] ch_select_latched;                // ch_select captured when a sample arrives
    wire we;                                    // write the new sample into sample_buffer

    // Memory interface (lane i is at [i*WIDTH +: WIDTH] in each bus)
    wire signed [LANES*COEF_W-1:0] current_coeffs;     // coefficient for each lane's tap, addressed last cycle
    wire [IDX_W-1:0] coeff_index;               // k, truncated to coef_rom's address width
    wire signed [LANES*SAMPLE_W-1:0] sample1_array;    // x[n-t] for each lane's tap t
    wire signed [LANES*SAMPLE_W-1:0] sample2_array;    // x[n-116+t] for each lane's tap t

    // Pipeline flags: last_tap_* marks the last step of the sweep (it holds the centre tap),
    // valid_* marks cycles holding real step data. Suffix = stage the data is in.
    reg last_tap_mem;
    reg last_tap_pre;
    reg last_tap_mult;
    reg last_tap_acc;
    reg valid_mem;
    reg valid_pre;
    reg valid_mult;

    // Datapath
    wire [LANES*PROD_W-1:0] product_flat;       // every lane's product, packed (lane i at [i*PROD_W +: PROD_W])
    reg signed [ACC_W-1:0] lane_sum;            // sum of all lane products this clock
    integer m;                                  // loop index for lane_sum
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
                S_SWEEP: if (k == STEPS-1) state <= S_DRAIN;     // last step addressed
                S_DRAIN: if (last_tap_acc) state <= S_IDLE;      // last step has been accumulated
                default: state <= S_IDLE; // if undefined state
            endcase
        end
    end

    // k counting process
    // 0 in IDLE, steps 0..STEPS-1 in SWEEP, then holds at STEPS-1 in DRAIN
    always @(posedge clk) begin
        case (state)
            S_IDLE:  k <= 0;
            S_SWEEP: if (k != STEPS-1) k <= k + 1;
            S_DRAIN: k <= STEPS-1;
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
        .TAP_COUNT  (TAP_COUNT),
        .LANES      (LANES)
    ) coef_rom_inst (
        .clk            (clk),
        .ch_select      (ch_select_latched),
        .tap_index      (coeff_index),
        .tap_out_flat   (current_coeffs)
    );

    // Instantiate sample buffer
    sample_buffer #(
        .BUFFER_COUNT   (BUFF_SZ),
        .DATA_WIDTH     (SAMPLE_W),
        .LANES          (LANES)
    ) sample_buff_inst (
        .clk    (clk),
        .rst    (rst),
        .we     (we),
        .wd     (sample_in),
        .k      (k),
        .sample1_flat(sample1_array),
        .sample2_flat(sample2_array)
    );

    //====================================================
    // Pipeline flags
    //====================================================

    // last_tap_mem process: high in the cycle the memory outputs hold the last step (centre tap)
    always @(posedge clk) begin
        if (state == S_SWEEP && k == STEPS-1)
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

    // valid_mem process: high for the STEPS cycles the memory outputs hold real steps
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
    // Datapath: one pre-add + multiplier per lane
    //====================================================
    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin : lane

            // Lane that holds the centre tap on the last step (e.g. 58 - 14*4 = 2 for LANES = 4)
            localparam CENTRE_LANE = (TAP_COUNT-1) - (STEPS-1)*LANES;

            // This lane's operands, pulled out of the buses INTO signed wires.
            // (A part-select is always unsigned, so it must be assigned to a signed wire
            // before it is used in arithmetic or negative values would be zero-extended.)
            wire signed [SAMPLE_W-1:0] s1 = sample1_array[i*SAMPLE_W +: SAMPLE_W];
            wire signed [SAMPLE_W-1:0] s2 = sample2_array[i*SAMPLE_W +: SAMPLE_W];
            wire signed [COEF_W-1:0]   c  = current_coeffs[i*COEF_W +: COEF_W];

            reg signed [COEF_W-1:0]   coef_d_i;     // coefficient delayed one cycle to meet pre_sum
            reg signed [SAMPLE_W:0]   pre_sum_i;    // 17 bits: one wider than a sample so the sum can't overflow
            reg signed [PROD_W-1:0]   product_i;    // 33 bits: 17-bit pre_sum x 16-bit coefficient

            // coef_d process: coefficient waits one cycle so it lines up with pre_sum at the multiplier
            always @(posedge clk) begin coef_d_i <= c; end

            // pre_sum process: the centre tap has no partner sample, so its lane skips the pre-add
            always @(posedge clk) begin
                if (last_tap_mem && (i == CENTRE_LANE))
                    pre_sum_i <= s1;
                else
                    pre_sum_i <= s1 + s2;
            end

            // product process
            always @(posedge clk) begin product_i <= pre_sum_i * coef_d_i; end

            assign product_flat[i*PROD_W +: PROD_W] = product_i;
        end
    endgenerate

    // lane_sum process: add all the lane products (combinational, same stage as the accumulate)
    always @(*) begin
        lane_sum = {ACC_W{1'b0}};
        for (m = 0; m < LANES; m = m + 1)
            lane_sum = lane_sum + $signed(product_flat[m*PROD_W +: PROD_W]);
    end

    // acc process: cleared in IDLE, adds the lane sum only on cycles holding a real step,
    // and holds the finished sum through DRAIN
    always @(posedge clk) begin
        if (state == S_IDLE)
            acc <= {ACC_W{1'b0}};
        else if (valid_mult)
            acc <= acc + lane_sum;
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