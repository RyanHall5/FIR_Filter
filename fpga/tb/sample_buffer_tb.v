//****************************************************
// Company : Rochester Institute of Technology (RIT )
// Engineer : Ryan Hall (rah3587@rit.edu)
//
// Create Date : 10/13/26
// Design Name : sample_buffer_tb
// Module Name : sample_buffer_tb - behavioral
// Project Name : FIR_Filter
// Target Devices : Basys3
//
// Description : self-checking testbench for sample_buffer with LANES read ports. Writes
//               random signed samples and, after chosen writes, sweeps the step input k
//               over every delay. Lane l of a step reads delay kj = k*LANES + l on
//               sample1 and delay LAST-kj on sample2; both are compared with a reference
//               model: the sample written d writes ago, or 0 if fewer than d+1 samples
//               exist. Lanes whose kj is past the last delay are not checked. Covers an
//               empty buffer, a partly filled one, several wrap-arounds and a reset in
//               the middle of a run. Prints PASS/FAIL.
//
// AI note     : generalized for LANES by Claude (Anthropic).
//****************************************************
`timescale 1ns/1ps

module sample_buffer_tb;
    parameter BUFFER_COUNT = 117;
    parameter DATA_WIDTH   = 16;
    parameter LANES        = 1;                                  // try 1, 2, 4, 6, 8, 50, 59
    localparam LAST  = BUFFER_COUNT - 1;
    localparam STEPS = (BUFFER_COUNT + LANES - 1) / LANES;       // steps needed to reach every delay

    reg clk = 0, rst = 1, we = 0;
    reg signed [DATA_WIDTH-1:0] wd = 0;
    reg [$clog2(BUFFER_COUNT)-1:0] k = 0;                        // a step number now
    wire [LANES*DATA_WIDTH-1:0] s1_flat, s2_flat;

    sample_buffer #(.BUFFER_COUNT(BUFFER_COUNT), .DATA_WIDTH(DATA_WIDTH), .LANES(LANES)) dut
        (.clk(clk), .rst(rst), .we(we), .wd(wd), .k(k),
         .sample1_flat(s1_flat), .sample2_flat(s2_flat));

    always #5 clk = ~clk;

    reg signed [DATA_WIDTH-1:0] w [0:4095];   // every sample written since reset
    integer n = 0, errors = 0, checks = 0;
    integer kk, ll, kj, i, seed;
    reg signed [DATA_WIDTH-1:0] got1, got2;

    function signed [DATA_WIDTH-1:0] model;
        input integer d;
        begin
            if (d < n) model = w[n-1-d]; else model = 0;
        end
    endfunction

    task write_sample;
        input signed [DATA_WIDTH-1:0] v;
        begin
            @(negedge clk); we = 1; wd = v;
            @(negedge clk); we = 0;
            w[n] = v; n = n + 1;
        end
    endtask

    // Sweep every step; check each lane whose delay is in range
    task check_all_steps;
        begin
            for (kk = 0; kk < STEPS; kk = kk + 1) begin
                @(negedge clk); k = kk;
                @(posedge clk); #1;
                for (ll = 0; ll < LANES; ll = ll + 1) begin
                    kj = kk*LANES + ll;
                    if (kj <= LAST) begin
                        got1 = s1_flat[ll*DATA_WIDTH +: DATA_WIDTH];
                        got2 = s2_flat[ll*DATA_WIDTH +: DATA_WIDTH];
                        checks = checks + 1;
                        if (got1 !== model(kj) || got2 !== model(LAST-kj)) begin
                            errors = errors + 1;
                            if (errors < 10)
                                $display("FAIL n=%0d step=%0d lane=%0d (delay %0d): s1=%0d exp %0d, s2=%0d exp %0d",
                                         n, kk, ll, kj, got1, model(kj), got2, model(LAST-kj));
                        end
                    end
                end
            end
        end
    endtask

    initial begin
        seed = 7;
        $display("sample_buffer testbench: LANES %0d, %0d steps", LANES, STEPS);
        repeat (3) @(negedge clk);
        rst = 0;
        check_all_steps;                              // empty: all zeros
        for (i = 0; i < 3*BUFFER_COUNT + 5; i = i + 1) begin
            write_sample($random(seed));             // random signed values incl. negatives
            if (i < 8 || i == BUFFER_COUNT-2 || i == BUFFER_COUNT-1 || i == BUFFER_COUNT ||
                i == 2*BUFFER_COUNT || i == 3*BUFFER_COUNT+4 || (i % 17) == 0)
                check_all_steps;
        end
        // reset mid-run: history must read as zeros again
        @(negedge clk); rst = 1; @(negedge clk); rst = 0; n = 0;
        check_all_steps;
        for (i = 0; i < 20; i = i + 1) write_sample($random(seed));
        check_all_steps;
        if (errors == 0) $display("PASS: sample_buffer(%0d), LANES %0d, %0d lane reads checked", BUFFER_COUNT, LANES, checks);
        else             $display("FAIL: sample_buffer(%0d), LANES %0d, %0d errors in %0d lane reads", BUFFER_COUNT, LANES, errors, checks);
        $finish;
    end
endmodule