//****************************************************
// Company : Rochester Institute of Technology (RIT )
// Engineer : Ryan Hall (rah3587@rit.edu)
//
// Create Date : 10/2/26
// Design Name : spi_slave
// Module Name : spi_slave - behavioral
// Project Name : FIR_Filter
// Target Devices : Basys3
//
// AI note     : Comments, code organization, and Synchronous reset(with all power-up initializers 
//               removed for ASIC synthesis) were written by Claude. 
//
// Description : logic for spi slave input/output
//
// Protocol    : SPI mode 0 (MOSI sampled on SCK rising, MISO changes on SCK falling),
//               MSB first, 16-bit words, CS_n active low. One CS_n-low frame can carry
//               many words back to back; the bit counters wrap every 16 bits.
//
// Receive     : Each complete word appears on word_received (held until the next word)
//               and word_valid pulses for one FPGA_clk in the same cycle.
//
// Transmit    : The word sent on MISO is tx_word. It is sampled into tx_snapshot at the
//               start of every 16-bit slot (CS falling, then each time the bit counter
//               wraps), so it cannot change in the middle of a word. The slot's first
//               bit is taken from tx_word directly because tx_snapshot updates on that
//               same clock edge. To echo the input, connect tx_word to word_received:
//               the word received in slot k then comes back in slot k+1.
//
// Reset       : Synchronous, active high (rst). No register has a power-up initializer,
//               because ASIC flops have no initial state. in_chunk and tx_snapshot are
//               not reset: they are fully overwritten (in_chunk shifts out after 16 bits,
//               tx_snapshot reloads at every slot start) before their values are used.
//
// Clocking    : Everything runs on FPGA_clk (100 MHz). SCK, CS_n and MOSI come from the
//               STM32 asynchronously, so they are synchronized first and SCK/CS_n edges
//               are detected as one-FPGA_clk strobes rather than used as clocks.
//****************************************************
module spi_slave (
    input wire FPGA_clk,
    input wire rst,                      // synchronous reset, active high
    input wire SCK,
    input wire CS_n,
    input wire MOSI,
    input wire [15:0] tx_word,           // word to send on MISO (sampled at the start of each slot)

    output reg word_valid,               // one-cycle pulse: a complete word is in word_received
    output wire MISO,
    output wire [15:0] word_received     // last complete word; the FIR core's sample_in
);

    //====================================================
    // Input synchronization
    //====================================================
    // [2] = first stage (may be metastable, never use), [1] = synchronized, [0] = delayed copy
    // (ascending ranges: a new sample enters at [2] and shifts toward [0])
    reg [0:2] SCK_pipe;
    reg [0:2] CS_n_pipe;
    reg [0:1] MOSI_pipe;

    // SCK_pipe process
    always @(posedge FPGA_clk) begin
        if (rst)
            SCK_pipe <= 3'b000;
        else
            SCK_pipe <= {SCK_pipe[1], SCK_pipe[2], SCK};
    end

    // CS_n_pipe process
    always @(posedge FPGA_clk) begin
        if (rst)
            CS_n_pipe <= 3'b111;
        else
            CS_n_pipe <= {CS_n_pipe[1], CS_n_pipe[2], CS_n};
    end

    // MOSI_pipe process
    always @(posedge FPGA_clk) begin
        if (rst)
            MOSI_pipe <= 2'b00;
        else
            MOSI_pipe <= {MOSI_pipe[1], MOSI};
    end

    wire SCK_sync  = SCK_pipe[1];
    wire CS_n_sync = CS_n_pipe[1];
    wire MOSI_sync = MOSI_pipe[0];   // second stage, same depth as SCK_sync

    //====================================================
    // Edge detection
    //====================================================
    // Strobes are one FPGA_clk cycle wide, all from synchronized stages
    wire SCK_rising  = ~SCK_pipe[0] & SCK_pipe[1];
    wire SCK_falling = SCK_pipe[0] & ~SCK_pipe[1];
    wire CS_rising   = ~CS_n_pipe[0] & CS_n_pipe[1];
    wire CS_falling  = CS_n_pipe[0] & ~CS_n_pipe[1];

    //====================================================
    // Receive (MOSI -> last_word)
    //====================================================
    // Bits shift into in_chunk on each SCK rising edge; on the 16th bit the finished
    // word is copied to last_word, which holds until the next word completes.
    reg [15:0] in_chunk;
    reg [15:0] last_word;
    reg [3:0] MOSI_counter;

    // in_chunk process (holds its value between SCK edges)
    always @(posedge FPGA_clk) begin
        if (CS_n_sync == 1'b0 && SCK_rising == 1'b1)
            in_chunk <= {in_chunk[14:0], MOSI_sync};
    end

    // MOSI_counter process: counts bits within a word, wraps 15 -> 0 on its own
    always @(posedge FPGA_clk) begin
        if (rst || CS_n_sync == 1'b1)
            MOSI_counter <= 4'h0;
        else if (SCK_rising == 1'b1)
            MOSI_counter <= MOSI_counter + 1;
    end

    // word_valid pulse process: high for one clock when the 16th bit arrives
    always @(posedge FPGA_clk) begin
        if (rst)
            word_valid <= 1'b0;
        else if (CS_n_sync == 1'b0 && SCK_rising == 1'b1 && MOSI_counter == 4'hF)
            word_valid <= 1'b1;
        else
            word_valid <= 1'b0;
    end

    // last_word process (holds its value until the next word completes)
    always @(posedge FPGA_clk) begin
        if (rst)
            last_word <= 16'h0000;
        else if (CS_n_sync == 1'b0 && SCK_rising == 1'b1 && MOSI_counter == 4'hF)
            last_word <= {in_chunk[14:0], MOSI_sync};
    end

    //====================================================
    // Transmit (tx_word -> MISO)
    //====================================================
    reg [3:0] MISO_counter;               // index of the next bit to send within tx_snapshot
    reg [15:0] tx_snapshot;               // tx_word frozen for the slot being sent
    reg tx_outbit;

    // Start of a transmit slot: CS just fell, or the counter wrapped and the next
    // falling edge begins a new 16-bit word
    wire load_tx = CS_falling ||
                   (CS_n_sync == 1'b0 && SCK_falling == 1'b1 && MISO_counter == 4'hF);

    // MISO_counter process
    always @(posedge FPGA_clk) begin
        if (rst || CS_falling == 1'b1)
            MISO_counter <= 4'hE;
        else if ((CS_n_sync == 1'b0) && (SCK_falling == 1'b1))
            MISO_counter <= MISO_counter - 1;      // wraps 0 -> 15 on its own
    end

    // tx_snapshot process
    always @(posedge FPGA_clk) begin
        if (load_tx == 1'b1)
            tx_snapshot <= tx_word;
    end

    // tx_outbit process
    always @(posedge FPGA_clk) begin
        if (rst)
            tx_outbit <= 1'b0;
        else if (load_tx == 1'b1)
            tx_outbit <= tx_word[15];              // bit 15 straight from tx_word (snapshot updates this same edge)
        else if ((CS_n_sync == 1'b0) && (SCK_falling == 1'b1))
            tx_outbit <= tx_snapshot[MISO_counter];
    end

    //====================================================
    // Outputs
    //====================================================
    assign MISO = tx_outbit;
    assign word_received = last_word;

endmodule