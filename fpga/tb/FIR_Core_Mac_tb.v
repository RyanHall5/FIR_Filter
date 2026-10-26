//****************************************************
// Company : Rochester Institute of Technology (RIT )
// Engineer : Ryan Hall (rah3587@rit.edu)
//
// Create Date : 10/15/26
// Design Name : FIR_Core_MAC_tb
// Module Name : FIR_Core_MAC_tb - behavioral
// Project Name : FIR_Filter
// Target Devices : Basys3
//
// AI note     : This testbench was written by Claude (Anthropic) at the author's request.
//               The design under test, FIR_Core_MAC, was written by the author.
//
// Description : self-checking testbench for FIR_Core_MAC. Feeds the MATLAB golden-model
//               input vectors through the core, one sample_valid pulse per sample, and
//               compares every sample_out against the matching expected vector, matching
//               by output index (the expected files assume no latency). Covers impulse,
//               step, stress, noise and composite inputs on all three channels, plus
//               - exactly one out_valid pulse per input sample, each lasting one clock
//               - the accumulator's upper bits equal the sign bit (no 16-bit overflow)
//               - ch_select is latched: it is changed right after each sample_valid pulse
//               Prints the first mismatches, a per-test PASS/FAIL, and a final summary.
//
// Setup       : Run from a directory containing the .hex files from
//               matlab/data/vectors (coef_ch1/2/3.hex, in_*.hex, exp_*.hex), because
//               $readmemh paths are relative to the simulator's working directory.
//               In Vivado, add the .hex files as simulation sources.
//****************************************************
`timescale 1ns/1ps

module FIR_Core_MAC_tb;

    // ---------------- Parameters (must match the DUT and fir_params.txt) ----------------
    localparam COEF_W    = 16;
    localparam SAMPLE_W  = 16;
    localparam ACC_W     = 39;
    localparam SHIFT     = 16;
    localparam TAP_COUNT = 59;

    localparam MAX_SAMPLES = 8192;   // longest vector (noise, composite)
    localparam GAP_CLKS    = 70;     // clocks between sample_valid pulses (the core needs 64)
    localparam RUN_LONG    = 1;      // 1 = include the 8192-sample noise and composite vectors

    // Upper accumulator bits that must all equal the sign bit of the 16-bit output slice
    localparam HI_W = ACC_W - SHIFT - SAMPLE_W + 1;

    // ---------------- DUT signals ----------------
    reg                       clk          = 1'b0;
    reg                       rst          = 1'b1;
    reg                       sample_valid = 1'b0;
    reg signed [SAMPLE_W-1:0] sample_in    = {SAMPLE_W{1'b0}};
    reg [1:0]                 ch_select    = 2'b00;
    wire signed [SAMPLE_W-1:0] sample_out;
    wire                      out_valid;

    FIR_Core_MAC #(
        .COEF_W    (COEF_W),
        .SAMPLE_W  (SAMPLE_W),
        .ACC_W     (ACC_W),
        .SHIFT     (SHIFT),
        .TAP_COUNT (TAP_COUNT)
    ) dut (
        .clk          (clk),
        .rst          (rst),
        .sample_valid (sample_valid),
        .sample_in    (sample_in),
        .ch_select    (ch_select),
        .sample_out   (sample_out),
        .out_valid    (out_valid)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // ---------------- Vector storage and bookkeeping ----------------
    reg signed [SAMPLE_W-1:0] in_mem  [0:MAX_SAMPLES-1];
    reg signed [SAMPLE_W-1:0] exp_mem [0:MAX_SAMPLES-1];

    integer n_samples;        // samples in the current input vector
    integer n_expected;       // lines in the current expected vector
    integer out_count;        // outputs seen so far in the current test
    integer errors;           // errors in the current test
    integer total_tests   = 0;
    integer failed_tests  = 0;
    integer total_errors  = 0;
    integer latency       = 0;
    integer i;
    reg     active        = 1'b0;   // monitor only checks while a test is running

    // Clocks since the last sample_valid pulse (used to report latency)
    integer clks_since_valid = 0;
    always @(posedge clk) begin
        if (sample_valid) clks_since_valid <= 1;
        else              clks_since_valid <= clks_since_valid + 1;
    end

    // out_valid delayed one clock, to detect pulses longer than one cycle
    reg out_valid_prev = 1'b0;
    always @(posedge clk) out_valid_prev <= out_valid;

    // Upper accumulator bits (hierarchical reference into the DUT)
    wire [HI_W-1:0] acc_hi = dut.acc[ACC_W-1 -: HI_W];

    // ---------------- Output monitor ----------------
    always @(posedge clk) begin
        if (active) begin
            if (out_valid) begin
                if (out_valid_prev) begin
                    errors = errors + 1;
                    $display("FAIL: out_valid high for more than one clock (output %0d)", out_count);
                end
                if (out_count < n_samples) begin
                    if (sample_out !== exp_mem[out_count]) begin
                        errors = errors + 1;
                        if (errors <= 10)
                            $display("FAIL: output %0d: got %0d (0x%h), expected %0d (0x%h)",
                                     out_count, sample_out, sample_out,
                                     exp_mem[out_count], exp_mem[out_count]);
                    end
                end else begin
                    errors = errors + 1;
                    $display("FAIL: extra out_valid after all %0d outputs", n_samples);
                end
                if (out_count == 0) latency = clks_since_valid;
                out_count = out_count + 1;
            end

            // Overflow check: when the sum is complete, bits above the 16-bit slice must
            // all match its sign bit, otherwise the output has wrapped.
            if (dut.last_tap_acc) begin
                if (!((&acc_hi) || !(|acc_hi))) begin
                    errors = errors + 1;
                    $display("FAIL: accumulator overflow at output %0d (upper bits 0x%h)",
                             out_count, acc_hi);
                end
            end
        end
    end

    // ---------------- Helpers ----------------

    // Number of values in a hex file (one per line)
    task count_lines;
        input  [8*32-1:0] fname;
        output integer    count;
        integer fd, code, tmp;
        begin
            count = 0;
            fd = $fopen(fname, "r");
            if (fd == 0) begin
                $display("FAIL: cannot open %0s", fname);
            end else begin
                code = $fscanf(fd, "%h\n", tmp);
                while (code == 1) begin
                    count = count + 1;
                    code = $fscanf(fd, "%h\n", tmp);
                end
                $fclose(fd);
            end
        end
    endtask

    // Run one input vector through the core on channel ch and check every output
    task run_test;
        input [8*32-1:0] in_file;
        input [8*32-1:0] exp_file;
        input integer    ch;
        begin
            // Load vectors
            for (i = 0; i < MAX_SAMPLES; i = i + 1) begin
                in_mem[i]  = {SAMPLE_W{1'b0}};
                exp_mem[i] = {SAMPLE_W{1'b0}};
            end
            count_lines(in_file,  n_samples);
            count_lines(exp_file, n_expected);
            $readmemh(in_file,  in_mem);
            $readmemh(exp_file, exp_mem);

            errors    = 0;
            out_count = 0;
            if (n_samples != n_expected || n_samples == 0 || n_samples > MAX_SAMPLES) begin
                errors = errors + 1;
                $display("FAIL: vector sizes: %0d inputs, %0d expected (max %0d)",
                         n_samples, n_expected, MAX_SAMPLES);
                n_samples = 0;
            end

            // Reset so the history starts at zero, as in the golden model
            rst = 1'b1; sample_valid = 1'b0; ch_select = 2'b00;
            repeat (4) @(negedge clk);
            rst = 1'b0;
            repeat (2) @(negedge clk);

            // Feed samples, one sample_valid pulse each, driven on the falling edge
            active = 1'b1;
            for (i = 0; i < n_samples; i = i + 1) begin
                @(negedge clk);
                sample_valid = 1'b1;
                sample_in    = in_mem[i];
                ch_select    = ch[1:0];
                @(negedge clk);
                sample_valid = 1'b0;
                ch_select    = ~ch[1:0];     // change it: the core must have latched the channel
                repeat (GAP_CLKS - 1) @(negedge clk);
            end
            repeat (GAP_CLKS) @(negedge clk);   // let the last output finish
            active = 1'b0;

            if (out_count != n_samples) begin
                errors = errors + 1;
                $display("FAIL: expected %0d outputs, got %0d", n_samples, out_count);
            end

            total_tests  = total_tests + 1;
            total_errors = total_errors + errors;
            if (errors == 0) begin
                $display("PASS: %0s ch%0d, %0d outputs checked", exp_file, ch, out_count);
            end else begin
                failed_tests = failed_tests + 1;
                $display("FAIL: %0s ch%0d, %0d errors in %0d outputs", exp_file, ch, errors, out_count);
            end
        end
    endtask

    // ---------------- Test sequence ----------------
    initial begin
        $display("FIR_Core_MAC testbench: %0d taps, COEF_W %0d, SHIFT %0d, ACC_W %0d",
                 TAP_COUNT, COEF_W, SHIFT, ACC_W);

        // Impulse: the output is the coefficient sequence, so this shows ordering bugs first
        run_test("in_impulse.hex", "exp_impulse_ch1.hex", 1);
        run_test("in_impulse.hex", "exp_impulse_ch2.hex", 2);
        run_test("in_impulse.hex", "exp_impulse_ch3.hex", 3);

        // Step: checks that the accumulation sums correctly
        run_test("in_step.hex", "exp_step_ch1.hex", 1);
        run_test("in_step.hex", "exp_step_ch2.hex", 2);
        run_test("in_step.hex", "exp_step_ch3.hex", 3);

        // Stress: in_stress_chN is the worst case for channel N, run through every channel
        run_test("in_stress_ch1.hex", "exp_stress_ch1_ch1.hex", 1);
        run_test("in_stress_ch1.hex", "exp_stress_ch1_ch2.hex", 2);
        run_test("in_stress_ch1.hex", "exp_stress_ch1_ch3.hex", 3);
        run_test("in_stress_ch2.hex", "exp_stress_ch2_ch1.hex", 1);
        run_test("in_stress_ch2.hex", "exp_stress_ch2_ch2.hex", 2);
        run_test("in_stress_ch2.hex", "exp_stress_ch2_ch3.hex", 3);
        run_test("in_stress_ch3.hex", "exp_stress_ch3_ch1.hex", 1);
        run_test("in_stress_ch3.hex", "exp_stress_ch3_ch2.hex", 2);
        run_test("in_stress_ch3.hex", "exp_stress_ch3_ch3.hex", 3);

        // Noise and composite: general correctness (long)
        if (RUN_LONG) begin
            run_test("in_noise.hex",     "exp_noise_ch1.hex",     1);
            run_test("in_noise.hex",     "exp_noise_ch2.hex",     2);
            run_test("in_noise.hex",     "exp_noise_ch3.hex",     3);
            run_test("in_composite.hex", "exp_composite_ch1.hex", 1);
            run_test("in_composite.hex", "exp_composite_ch2.hex", 2);
            run_test("in_composite.hex", "exp_composite_ch3.hex", 3);
        end

        $display("Latency: %0d clocks from sample_valid to out_valid", latency);
        if (failed_tests == 0)
            $display("PASS: FIR_Core_MAC, %0d tests, 0 errors", total_tests);
        else
            $display("FAIL: FIR_Core_MAC, %0d of %0d tests failed, %0d errors",
                     failed_tests, total_tests, total_errors);
        $finish;
    end

    // Safety net: never hang
    initial begin
        #400000000;
        $display("FAIL: testbench timed out");
        $finish;
    end

endmodule