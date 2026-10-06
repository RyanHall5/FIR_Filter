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
// Description : board-level wrapper; connects spi_slave to Basys3 pins
//****************************************************
module top (
    input  wire        clk,      // 100 MHz Basys3 clock
    input  wire        SCK,      // from STM32 PA5
    input  wire        CS_n,     // from STM32 PB6
    input  wire        MOSI,     // from STM32 PA7
    output wire        MISO,     // to STM32 PA6
    output wire [15:0] led       // shows last complete word received
);

    spi_slave u_spi_slave (
        .FPGA_clk      (clk),
        .SCK           (SCK),
        .CS_n          (CS_n),
        .MOSI          (MOSI),
        .MISO          (MISO),
        .word_received (led)
    );

endmodule