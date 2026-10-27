//****************************************************
// Design Name : coef_rom_tb
// Module Name : coef_rom_tb - behavioral
// Project Name : FIR_Filter
// Target Devices : Basys3
//
// Description : self-checking testbench for coef_rom with LANES read ports. Each
//               read presents a STEP; lane l must return tap (step*LANES + l), or 0
//               when that index is 59 or more (padding). Checks every step of every
//               channel (and ch_select = 0), the one-cycle read latency, and that
//               negative coefficients stay negative. Prints PASS/FAIL.
//
// AI note     : generalized for LANES by Claude.
//****************************************************
`timescale 1ns/1ps

module coef_rom_tb;

    // ---------------- Parameters (must match the DUT / MATLAB fir_params.txt) ----------------
    localparam COEF_WIDTH = 16;
    localparam TAP_COUNT  = 59;
    localparam LANES      = 4;                                   // try 1, 2, 4, 8
    localparam IDX_WIDTH  = $clog2(TAP_COUNT);
    localparam STEPS      = (TAP_COUNT + LANES - 1) / LANES;     // ceil(59/LANES)
    localparam PAD_SLOTS  = STEPS*LANES - TAP_COUNT;             // lanes that must read 0

    // ---------------- DUT signals ----------------
    reg                           clk       = 1'b0;
    reg  [1:0]                    ch_select = 2'b00;
    reg  [IDX_WIDTH-1:0]          tap_index = {IDX_WIDTH{1'b0}};   // a step number now
    wire [LANES*COEF_WIDTH-1:0]   tap_out_flat;

    // ---------------- Reference copies of the same hex files ----------------
    reg signed [COEF_WIDTH-1:0] ref_ch1 [0:TAP_COUNT-1];
    reg signed [COEF_WIDTH-1:0] ref_ch2 [0:TAP_COUNT-1];
    reg signed [COEF_WIDTH-1:0] ref_ch3 [0:TAP_COUNT-1];

    integer errors = 0;
    integer checks = 0;
    integer neg_count [1:3];
    integer ch, k, l;

    coef_rom #(
        .COEF_WIDTH (COEF_WIDTH),
        .TAP_COUNT  (TAP_COUNT),
        .LANES      (LANES)
    ) dut (
        .clk          (clk),
        .ch_select    (ch_select),
        .tap_index    (tap_index),
        .tap_out_flat (tap_out_flat)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // Lane l's slice of the output bus
    function signed [COEF_WIDTH-1:0] lane_val;
        input integer lane;
        begin
            lane_val = tap_out_flat[lane*COEF_WIDTH +: COEF_WIDTH];
        end
    endfunction

    // Expected coefficient for a (channel, tap index) pair.
    // ch_select = 0 -> 0, and any index past the last real tap (padding) -> 0.
    function signed [COEF_WIDTH-1:0] expected;
        input [1:0] c;
        input integer idx;
        begin
            if (idx >= TAP_COUNT)
                expected = {COEF_WIDTH{1'b0}};
            else
                case (c)
                    2'b01:   expected = ref_ch1[idx];
                    2'b10:   expected = ref_ch2[idx];
                    2'b11:   expected = ref_ch3[idx];
                    default: expected = {COEF_WIDTH{1'b0}};
                endcase
        end
    endfunction

    // Apply a step, check the outputs have NOT changed yet (registered read),
    // then check every lane after the next rising edge.
    reg [LANES*COEF_WIDTH-1:0] before;
    task check_read;
        input [1:0] c;
        input integer step;
        integer lane;
        reg signed [COEF_WIDTH-1:0] expv;
        reg signed [COEF_WIDTH-1:0] got;
        begin
            @(negedge clk);
            before    = tap_out_flat;
            ch_select = c;
            tap_index = step;
            #1;
            if (tap_out_flat !== before) begin
                $display("FAIL: output changed before the clock edge (ch %0d step %0d)", c, step);
                errors = errors + 1;
            end
            @(posedge clk);
            #1;
            for (lane = 0; lane < LANES; lane = lane + 1) begin
                expv   = expected(c, step*LANES + lane);
                got    = lane_val(lane);
                checks = checks + 1;
                if (got !== expv) begin
                    $display("FAIL: ch %0d step %0d lane %0d (tap %0d): expected %0d (0x%h), got %0d (0x%h)",
                             c, step, lane, step*LANES + lane, expv, expv, got, got);
                    errors = errors + 1;
                end
            end
        end
    endtask

    initial begin
        $readmemh("coef_ch1.hex", ref_ch1);
        $readmemh("coef_ch2.hex", ref_ch2);
        $readmemh("coef_ch3.hex", ref_ch3);
        neg_count[1] = 0; neg_count[2] = 0; neg_count[3] = 0;

        $display("coef_rom testbench: LANES %0d, %0d steps, %0d padded slots", LANES, STEPS, PAD_SLOTS);

        repeat (3) @(posedge clk);

        // ch_select = 0 must give zero for every lane of every step
        for (k = 0; k < STEPS; k = k + 1)
            check_read(2'b00, k);

        // channels 1..3: every step, in order; count negatives on real taps only
        for (ch = 1; ch <= 3; ch = ch + 1)
            for (k = 0; k < STEPS; k = k + 1) begin
                check_read(ch[1:0], k);
                for (l = 0; l < LANES; l = l + 1)
                    if (k*LANES + l < TAP_COUNT && lane_val(l) < 0)
                        neg_count[ch] = neg_count[ch] + 1;
            end

        // Back-to-back channel changes at the last step (it holds the centre tap)
        for (k = 0; k < 6; k = k + 1) begin
            check_read(2'b01, STEPS-1);
            check_read(2'b10, STEPS-1);
            check_read(2'b11, STEPS-1);
        end

        // Sign handling: every channel should contain negative coefficients
        for (ch = 1; ch <= 3; ch = ch + 1) begin
            $display("ch %0d: %0d of %0d coefficients are negative", ch, neg_count[ch], TAP_COUNT);
            if (neg_count[ch] == 0) begin
                $display("FAIL: ch %0d has no negative coefficients; sign handling or the hex file is wrong", ch);
                errors = errors + 1;
            end
        end

        // Show the interesting taps for eyeballing against the hex files
        for (ch = 1; ch <= 3; ch = ch + 1) begin
            check_read(ch[1:0], 0);
            $display("ch %0d tap  0 = %0d", ch, lane_val(0));
            check_read(ch[1:0], (TAP_COUNT-1)/LANES);
            $display("ch %0d tap %0d = %0d (centre, lane %0d)",
                     ch, TAP_COUNT-1, lane_val((TAP_COUNT-1)%LANES), (TAP_COUNT-1)%LANES);
        end

        if (errors == 0) $display("PASS: coef_rom, LANES %0d, %0d lane reads checked, 0 errors", LANES, checks);
        else             $display("FAIL: coef_rom, LANES %0d, %0d errors in %0d lane reads", LANES, errors, checks);
        $finish;
    end

    // Safety net: never hang
    initial begin
        #1000000;
        $display("FAIL: testbench timed out");
        $finish;
    end

endmodule