//****************************************************
// Company : Rochester Institute of Technology (RIT )
// Engineer : Ryan Hall (rah3587@rit.edu)
//
// Create Date : 10/2/26
// Design Name : spi_slave_tb
// Module Name : spi_slave_tb - behavioral
// Project Name : FIR_Filter
// Target Devices : Basys3
//
// AI note     : Updated by Claude (Anthropic) at the author's request, to match the new
//               spi_slave ports (rst, tx_word, word_valid) and to add the word_valid and
//               tx_word snapshot checks (Test 8). The SPI master model, the echo checks
//               and Tests 1 to 7 were written by the author.
//
// Description : testbench for logic for spi slave input/output
//               - Tests 1 to 7: tx_word is tied to word_received (echo), so the word
//                 received in one slot must come back in the next slot
//               - word_valid: exactly one single-clock pulse per complete word
//               - Test 8: tx_word is driven separately and changed mid-word; MISO must
//                 keep sending the value captured at the start of the word
//****************************************************
`timescale 1ns/1ps

module spi_slave_tb;

    // ---------------- Timing parameters ----------------
    localparam CLK_HALF = 5;     // 100 MHz FPGA clock (10 ns period)
    localparam SCK_HALF = 181;   // ~2.8 MHz SCK; odd value so SCK drifts against the FPGA clock

    // ---------------- Signals driven / observed ----------------
    reg         FPGA_clk = 1'b0;
    reg         SCK      = 1'b0;   // Mode 0: idles low
    reg         CS_n     = 1'b1;   // idles high
    reg         MOSI     = 1'b0;
    reg         rst      = 1'b1;   // synchronous reset, released after a few clocks
    wire        MISO;
    wire [15:0] word_received;
    wire        word_valid;

    // tx_word source: echo of word_received (Tests 1 to 7) or tb-driven (Test 8)
    reg         tx_sel   = 1'b0;
    reg  [15:0] tx_ext   = 16'h0000;
    wire [15:0] tx_word  = tx_sel ? tx_ext : word_received;

    // ---------------- Device under test ----------------
    spi_slave dut (
        .FPGA_clk      (FPGA_clk),
        .rst           (rst),
        .SCK           (SCK),
        .CS_n          (CS_n),
        .MOSI          (MOSI),
        .tx_word       (tx_word),
        .word_valid    (word_valid),
        .MISO          (MISO),
        .word_received (word_received)
    );

    // ---------------- FPGA clock generator ----------------
    always #(CLK_HALF) FPGA_clk = ~FPGA_clk;

    // ---------------- Reset ----------------
    initial begin
        repeat (5) @(posedge FPGA_clk);
        rst <= 1'b0;
    end

    // ---------------- Bookkeeping ----------------
    integer errors    = 0;
    integer checks    = 0;
    integer frame_num = 0;
    integer k;
    reg     ALL_TESTS_PASSED = 1'b0;     // the global result flag

    reg [15:0] tx_buf [0:127];           // words the "STM32" sends in the next frame
    reg [15:0] prev_last = 16'h0000;     // model: last complete word the slave has received

    // word_valid monitor: count pulses, flag any pulse longer than one clock
    integer valid_pulses = 0;            // word_valid pulses seen
    integer words_sent   = 0;            // complete words the master has sent
    reg     valid_prev   = 1'b0;
    always @(posedge FPGA_clk) begin
        valid_prev <= word_valid;
        if (word_valid === 1'b1) begin
            valid_pulses = valid_pulses + 1;
            if (valid_prev === 1'b1) begin
                errors = errors + 1;
                $display("[%0t ns] ERROR: word_valid high for more than one clock", $time);
            end
        end
    end

    // ---------------- Clock out nbits bits, MSB first (SPI Mode 0) ----------------
    // Drives MOSI, samples MISO at each rising edge, compares against 'expected'.
    task xfer_bits(input [15:0] tx, input [15:0] expected,
                   input integer nbits, input integer widx);
        integer i;
        begin
            for (i = 0; i < nbits; i = i + 1) begin
                MOSI = tx[15-i];              // master changes MOSI on the falling edge
                #(SCK_HALF);
                SCK = 1'b1;                   // rising edge: both sides sample
                checks = checks + 1;
                if (MISO !== expected[15-i]) begin   // !== also catches X/Z
                    errors = errors + 1;
                    if (errors <= 20)
                        $display("[%0t ns] ERROR frame %0d word %0d bit %0d: expected %b got %b (expected word %h)",
                                 $time, frame_num, widx, 15-i, expected[15-i], MISO, expected);
                end
                #(SCK_HALF);
                SCK = 1'b0;                   // falling edge
            end
        end
    endtask

    // ---------------- Send one frame ----------------
    // nwords     : number of complete 16-bit words
    // extra_bits : if >0, CS is released after this many bits of one more word (aborted frame)
    // gap_ns     : how long CS stays high afterwards
    task send_frame(input integer nwords, input integer extra_bits, input integer gap_ns);
        integer j;
        reg [15:0] expected;
        begin
            frame_num = frame_num + 1;
            CS_n = 1'b0;
            #(300);                           // time for CS to pass the synchronizer

            for (j = 0; j < nwords; j = j + 1) begin
                // Model: word j returns the word received just before it
                // (or the last word of the previous frame, for j == 0)
                if (j == 0) expected = prev_last;
                else        expected = tx_buf[j-1];
                xfer_bits(tx_buf[j], expected, 16, j);
            end

            if (extra_bits > 0) begin
                if (nwords == 0) expected = prev_last;
                else             expected = tx_buf[nwords-1];
                xfer_bits(tx_buf[nwords], expected, extra_bits, nwords);
            end

            #(SCK_HALF);
            CS_n = 1'b1;
            if (nwords > 0) prev_last = tx_buf[nwords-1];   // update the model
            words_sent = words_sent + nwords;
            #(gap_ns);

            // The debug port should show the last COMPLETE word
            checks = checks + 1;
            if (word_received !== prev_last) begin
                errors = errors + 1;
                $display("[%0t ns] ERROR frame %0d: word_received = %h, expected %h",
                         $time, frame_num, word_received, prev_last);
            end
        end
    endtask

    // ---------------- Snapshot test ----------------
    // tx_word is tb-driven. It is A55A when CS falls and changes to 1234 in the middle of
    // word 0. MISO must still finish word 0 as A55A (captured at the start of the word),
    // then send 1234 as word 1 (captured at the start of that word).
    task snapshot_test;
        integer i;
        reg [15:0] expected;
        begin
            frame_num = frame_num + 1;
            tx_sel = 1'b1;
            tx_ext = 16'hA55A;
            #(100);
            CS_n = 1'b0;
            #(300);
            for (i = 0; i < 32; i = i + 1) begin
                MOSI = 1'b0;
                if (i == 8) tx_ext = 16'h1234;                // change mid-word
                expected = (i < 16) ? 16'hA55A : 16'h1234;
                #(SCK_HALF);
                SCK = 1'b1;
                checks = checks + 1;
                if (MISO !== expected[15 - (i % 16)]) begin
                    errors = errors + 1;
                    if (errors <= 20)
                        $display("[%0t ns] ERROR snapshot frame %0d bit %0d: expected %b got %b (expected word %h)",
                                 $time, frame_num, i, expected[15 - (i % 16)], MISO, expected);
                end
                #(SCK_HALF);
                SCK = 1'b0;
            end
            #(SCK_HALF);
            CS_n = 1'b1;
            words_sent = words_sent + 2;
            #(1000);
            tx_sel = 1'b0;
            prev_last = 16'h0000;   // the all-zero words sent above are now the last received
        end
    endtask

    // ---------------- Watchdog ----------------
    initial begin
        #10_000_000;
        $display("TIMEOUT: testbench did not finish");
        $finish;
    end

    // ---------------- Main test sequence ----------------
    initial begin
        #203;   // let the synchronizers settle

        $display("Test 1: edge-case words (8000, FFFF, 0001, A5A5...)");
        tx_buf[0] = 16'h8000; tx_buf[1] = 16'hFFFF; tx_buf[2] = 16'h0001; tx_buf[3] = 16'hA5A5;
        tx_buf[4] = 16'h0000; tx_buf[5] = 16'h5A5A; tx_buf[6] = 16'h1234; tx_buf[7] = 16'hFEDC;
        send_frame(8, 0, 1000);

        $display("Test 2: 32-word ramp crossing 0x8000");
        for (k = 0; k < 32; k = k + 1) tx_buf[k] = 16'h7FF0 + k;
        send_frame(32, 0, 1000);

        $display("Test 3: single-word frame");
        tx_buf[0] = 16'hC3C3;
        send_frame(1, 0, 1000);

        $display("Test 4: frame aborted mid-word (3 words + 5 bits)");
        tx_buf[0] = 16'h1111; tx_buf[1] = 16'h2222; tx_buf[2] = 16'h3333; tx_buf[3] = 16'hFFFF;
        send_frame(3, 5, 1000);

        $display("Test 5: normal frame right after the abort");
        tx_buf[0] = 16'hDEAD; tx_buf[1] = 16'hBEEF; tx_buf[2] = 16'h0F0F; tx_buf[3] = 16'hF0F0;
        send_frame(4, 0, 1000);

        $display("Test 6: back-to-back frames, short CS-high gap");
        tx_buf[0] = 16'hAAAA; tx_buf[1] = 16'h5555;
        send_frame(2, 0, 400);
        tx_buf[0] = 16'h0F00; tx_buf[1] = 16'h00F0;
        send_frame(2, 0, 400);

        $display("Test 7: 100 random words");
        for (k = 0; k < 100; k = k + 1) tx_buf[k] = $urandom;
        send_frame(100, 0, 1000);

        $display("Test 8: tx_word changes mid-word (snapshot check)");
        snapshot_test;

        // word_valid must have pulsed exactly once per complete word
        checks = checks + 1;
        if (valid_pulses != words_sent) begin
            errors = errors + 1;
            $display("ERROR: %0d word_valid pulses for %0d complete words", valid_pulses, words_sent);
        end

        // ---------------- Summary ----------------
        if (errors == 0) begin
            ALL_TESTS_PASSED = 1'b1;
            $display("==============================================");
            $display("ALL TESTS PASSED (%0d checks)", checks);
            $display("==============================================");
        end else begin
            $display("==============================================");
            $display("TESTS FAILED: %0d errors out of %0d checks", errors, checks);
            $display("==============================================");
        end
        $finish;
    end

endmodule