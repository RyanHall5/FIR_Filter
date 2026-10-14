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
// Description : self-checking testbench for sample_buffer. Writes random signed
//               samples and, after chosen writes, reads every k and compares both
//               outputs with a reference model: the sample written d writes ago, or
//               0 if fewer than d+1 samples exist. Covers an empty buffer, a partly
//               filled one, several wrap-arounds and a reset in the middle of a run.
//               Prints PASS/FAIL.
//****************************************************
`timescale 1ns/1ps

module sample_buffer_tb;
    parameter BUFFER_COUNT = 117;
    parameter DATA_WIDTH   = 16;
    localparam LAST = BUFFER_COUNT - 1;

    reg clk = 0, rst = 1, we = 0;
    reg signed [DATA_WIDTH-1:0] wd = 0;
    reg [$clog2(BUFFER_COUNT)-1:0] k = 0;
    wire signed [DATA_WIDTH-1:0] s1, s2;

    sample_buffer #(.BUFFER_COUNT(BUFFER_COUNT), .DATA_WIDTH(DATA_WIDTH)) dut
        (.clk(clk), .rst(rst), .we(we), .wd(wd), .k(k), .sample1(s1), .sample2(s2));

    always #5 clk = ~clk;

    reg signed [DATA_WIDTH-1:0] w [0:4095];   // every sample written since reset
    integer n = 0, errors = 0, checks = 0;
    integer kk, i, seed;

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

    task check_all_k;
        begin
            for (kk = 0; kk < BUFFER_COUNT; kk = kk + 1) begin
                @(negedge clk); k = kk;
                @(posedge clk); #1;
                checks = checks + 1;
                if (s1 !== model(kk) || s2 !== model(LAST-kk)) begin
                    errors = errors + 1;
                    if (errors < 10)
                        $display("FAIL n=%0d k=%0d: s1=%0d exp %0d, s2=%0d exp %0d",
                                 n, kk, s1, model(kk), s2, model(LAST-kk));
                end
            end
        end
    endtask

    initial begin
        seed = 7;
        repeat (3) @(negedge clk);
        rst = 0;
        check_all_k;                                  // empty: all zeros
        for (i = 0; i < 3*BUFFER_COUNT + 5; i = i + 1) begin
            write_sample($random(seed));             // random signed values incl. negatives
            if (i < 8 || i == BUFFER_COUNT-2 || i == BUFFER_COUNT-1 || i == BUFFER_COUNT ||
                i == 2*BUFFER_COUNT || i == 3*BUFFER_COUNT+4 || (i % 17) == 0)
                check_all_k;
        end
        // reset mid-run: history must read as zeros again
        @(negedge clk); rst = 1; @(negedge clk); rst = 0; n = 0;
        check_all_k;
        for (i = 0; i < 20; i = i + 1) write_sample($random(seed));
        check_all_k;
        if (errors == 0) $display("PASS: sample_buffer(%0d), %0d reads checked", BUFFER_COUNT, checks);
        else             $display("FAIL: sample_buffer(%0d), %0d errors in %0d reads", BUFFER_COUNT, errors, checks);
        $finish;
    end
endmodule