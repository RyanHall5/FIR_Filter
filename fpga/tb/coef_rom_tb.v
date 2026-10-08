//****************************************************
// Company : Rochester Institute of Technology (RIT )
// Engineer : Ryan Hall (rah3587@rit.edu)
//
// Create Date : 10/7/26
// Design Name : coef_rom_tb
// Module Name : coef_rom_tb - behavioral
// Project Name : FIR_Filter
// Target Devices : Basys3
//
// Description : self-checking testbench for coef_rom. Checks every tap of every
//               channel (and ch_select = 0), the one-cycle read latency, and that
//               negative coefficients stay negative. Prints PASS/FAIL.
//****************************************************
`timescale 1ns/1ps

module coef_rom_tb;

    // ---------------- Parameters (must match the DUT / MATLAB fir_params.txt) ----------------
    localparam COEF_WIDTH = 16;
    localparam TAP_COUNT  = 59;
    localparam IDX_WIDTH  = $clog2(TAP_COUNT);

    // ---------------- DUT signals ----------------
    reg                          clk       = 1'b0;
    reg  [1:0]                   ch_select = 2'b00;
    reg  [IDX_WIDTH-1:0]         tap_index = {IDX_WIDTH{1'b0}};
    wire signed [COEF_WIDTH-1:0] tap_out;

    // ---------------- Reference copies of the same hex files ----------------
    // Loaded independently of the DUT, so this checks the DUT's indexing, channel
    // select, latency and sign handling (not the contents of the hex files themselves).
    reg signed [COEF_WIDTH-1:0] ref_ch1 [0:TAP_COUNT-1];
    reg signed [COEF_WIDTH-1:0] ref_ch2 [0:TAP_COUNT-1];
    reg signed [COEF_WIDTH-1:0] ref_ch3 [0:TAP_COUNT-1];

    integer errors = 0;
    integer checks = 0;
    integer neg_count [1:3];
    integer ch, k;

    coef_rom #(
        .COEF_WIDTH (COEF_WIDTH),
        .TAP_COUNT  (TAP_COUNT)
    ) dut (
        .clk       (clk),
        .ch_select (ch_select),
        .tap_index (tap_index),
        .tap_out   (tap_out)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // Expected coefficient for a (channel, index) pair; ch_select = 0 -> 0
    function signed [COEF_WIDTH-1:0] expected;
        input [1:0] c;
        input integer i;
        begin
            case (c)
                2'b01:   expected = ref_ch1[i];
                2'b10:   expected = ref_ch2[i];
                2'b11:   expected = ref_ch3[i];
                default: expected = {COEF_WIDTH{1'b0}};
            endcase
        end
    endfunction

    // Apply an address, check the output has NOT changed yet (registered read),
    // then check it after the next rising edge.
    reg signed [COEF_WIDTH-1:0] before;
    task check_read;
        input [1:0] c;
        input integer i;
        reg signed [COEF_WIDTH-1:0] exp;
        begin
            exp = expected(c, i);
            @(negedge clk);
            before    = tap_out;
            ch_select = c;
            tap_index = i;
            #1;
            if (tap_out !== before) begin
                $display("FAIL: output changed before the clock edge (ch %0d tap %0d)", c, i);
                errors = errors + 1;
            end
            @(posedge clk);
            #1;
            checks = checks + 1;
            if (tap_out !== exp) begin
                $display("FAIL: ch %0d tap %0d: expected %0d (0x%h), got %0d (0x%h)",
                         c, i, exp, exp, tap_out, tap_out);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $readmemh("coef_ch1.hex", ref_ch1);
        $readmemh("coef_ch2.hex", ref_ch2);
        $readmemh("coef_ch3.hex", ref_ch3);
        neg_count[1] = 0; neg_count[2] = 0; neg_count[3] = 0;

        repeat (3) @(posedge clk);

        // ch_select = 0 must give zero for every tap
        for (k = 0; k < TAP_COUNT; k = k + 1)
            check_read(2'b00, k);

        // channels 1..3: every tap, in order
        for (ch = 1; ch <= 3; ch = ch + 1)
            for (k = 0; k < TAP_COUNT; k = k + 1) begin
                check_read(ch[1:0], k);
                if (tap_out < 0) neg_count[ch] = neg_count[ch] + 1;
            end

        // Back-to-back channel changes at the same tap (centre tap = last entry)
        for (k = 0; k < 6; k = k + 1) begin
            check_read(2'b01, TAP_COUNT-1);
            check_read(2'b10, TAP_COUNT-1);
            check_read(2'b11, TAP_COUNT-1);
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
            $display("ch %0d tap  0 = %0d", ch, tap_out);
            check_read(ch[1:0], TAP_COUNT-1);
            $display("ch %0d tap %0d = %0d (centre)", ch, TAP_COUNT-1, tap_out);
        end

        if (errors == 0) $display("PASS: coef_rom, %0d reads checked, 0 errors", checks);
        else             $display("FAIL: coef_rom, %0d errors in %0d reads", errors, checks);
        $finish;
    end

    // Safety net: never hang
    initial begin
        #1000000;
        $display("FAIL: testbench timed out");
        $finish;
    end

endmodule