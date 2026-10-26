//****************************************************
// Company : Rochester Institute of Technology (RIT )
// Engineer : Ryan Hall (rah3587@rit.edu)
//
// Create Date : 10/2/26
// Design Name : top
// Module Name : top - structural
// Project Name : FIR_Filter
// Target Devices : Basys3
//
// AI note     : Comments and code organization were written by Claude.
//
// Description : board-level wrapper; connects spi_slave to the FIR core and Basys3 pins
//
// Data flow   : STM32 --SPI--> spi_slave --word--> FIR_Core_MAC --result--> spi_slave --SPI--> STM32
//
// Return path : fir_out is held in result_reg and offered to spi_slave as tx_word. The
//               filter needs 64 clocks per sample, far less than one SPI word, but the
//               word sent back in a slot is snapshotted at the slot start, so the result
//               for the sample received in slot n is returned in slot n+1. MATLAB must
//               shift the returned stream by one sample (and send one extra dummy frame
//               to flush the last result).
//
// Controls    : sw[1:0] selects the filter channel (01, 10, 11 = ch1..3; 00 = zero output)
//               btnC resets the design
//****************************************************
module top (
    input  wire        clk,      // 100 MHz Basys3 clock
    input  wire        SCK,      // from STM32 PA5
    input  wire        CS_n,     // from STM32 PB6
    input  wire        MOSI,     // from STM32 PA7
    input  wire [1:0]  sw,       // channel select
    input  wire        btnC,     // reset button
    output wire        MISO,     // to STM32 PA6
    output wire [15:0] led       // shows the last filtered output
);

    //====================================================
    // Reset
    //====================================================
    // btnC is asynchronous to clk: two flip-flops give a clean synchronous rst
    reg [1:0] rst_pipe;
    wire rst = rst_pipe[1];

    // rst_pipe process
    always @(posedge clk) begin
        rst_pipe <= {rst_pipe[0], btnC};
    end

    //====================================================
    // Channel select
    //====================================================
    // sw is asynchronous to clk; the core latches ch_select once per sample, so two
    // flip-flops here keep a mid-toggle value from reaching it
    reg [1:0] sw_meta;
    reg [1:0] sw_sync;

    // sw_meta process
    always @(posedge clk) begin
        sw_meta <= sw;
    end

    // sw_sync process
    always @(posedge clk) begin
        sw_sync <= sw_meta;
    end

    //====================================================
    // SPI link to the STM32
    //====================================================
    wire        word_valid;      // pulse: a new input word has arrived
    wire [15:0] rx_word;         // the received word (a signed 16-bit audio sample)
    wire [15:0] result_reg_w;    // word returned on MISO

    spi_slave u_spi_slave (
        .FPGA_clk      (clk),
        .rst           (rst),
        .SCK           (SCK),
        .CS_n          (CS_n),
        .MOSI          (MOSI),
        .tx_word       (result_reg_w),
        .word_valid    (word_valid),
        .MISO          (MISO),
        .word_received (rx_word)
    );

    //====================================================
    // FIR filter
    //====================================================
    wire signed [15:0] fir_out;
    wire               fir_valid;

    FIR_Core_MAC #(
        .COEF_W    (16),
        .SAMPLE_W  (16),
        .ACC_W     (39),
        .SHIFT     (16),
        .TAP_COUNT (59)
    ) u_fir (
        .clk          (clk),
        .rst          (rst),
        .sample_valid (word_valid),
        .sample_in    ($signed(rx_word)),
        .ch_select    (sw_sync),
        .sample_out   (fir_out),
        .out_valid    (fir_valid)
    );

    //====================================================
    // Result returned to the STM32
    //====================================================
    // Holds the latest filter output so MISO data is stable between results
    reg [15:0] result_reg;

    // result_reg process
    always @(posedge clk) begin
        if (rst)
            result_reg <= 16'h0000;
        else if (fir_valid)
            result_reg <= fir_out;
    end

    assign result_reg_w = result_reg;

    //====================================================
    // Debug LEDs
    //====================================================
    // Shows the last filter output, so you can see on the board that the filter is running
    assign led = result_reg;

endmodule