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
// Description : logic for spi slave input/output
//****************************************************
module spi_slave (
     input wire FPGA_clk,
     input wire SCK,
     input wire CS_n,
     input wire MOSI,
     
     output wire MISO,
     output wire [15:0] word_received // for debug only
);

    // Synchronize the inputs to FPGA clock
    // [2] = first stage (may be metastable, never use), [1] = synchronized, [0] = delayed copy
    reg [0:2] SCK_pipe  = 3'b000;
    reg [0:2] CS_n_pipe = 3'b111;
    reg [0:1] MOSI_pipe = 2'b00;
    always @(posedge FPGA_clk) begin
        SCK_pipe  <= {SCK_pipe[1],  SCK_pipe[2],  SCK};
        CS_n_pipe <= {CS_n_pipe[1], CS_n_pipe[2], CS_n};
        MOSI_pipe <= {MOSI_pipe[1], MOSI};
    end
    wire SCK_sync  = SCK_pipe[1];
    wire CS_n_sync = CS_n_pipe[1];
    wire MOSI_sync = MOSI_pipe[0];   // second stage, same depth as SCK_sync
    
    // Edge strobes (one FPGA_clk cycle wide), all from synchronized stages
    wire SCK_rising  = ~SCK_pipe[0] & SCK_pipe[1];
    wire SCK_falling = SCK_pipe[0] & ~SCK_pipe[1];
    wire CS_rising   = ~CS_n_pipe[0] & CS_n_pipe[1];
    wire CS_falling  = CS_n_pipe[0] & ~CS_n_pipe[1];
    
    // Receive 16-bit words
    reg [15:0] in_chunk = 16'h0000;
    reg [15:0] last_word = 16'h0000;
    reg [3:0] MOSI_counter = 4'h0;
    always @(posedge FPGA_clk) begin
        if (CS_n_sync == 1'b1) begin
            MOSI_counter <= 4'h0;                  // hold counter at 0 while deselected
        end
        else if (SCK_rising == 1'b1) begin
            in_chunk <= {in_chunk[14:0], MOSI_sync};
            MOSI_counter <= MOSI_counter + 1;
            if (MOSI_counter == 4'hF) begin        // this is the 16th bit
                last_word <= {in_chunk[14:0], MOSI_sync};
            end
        end
    end
    
    // Transmit 16-bit words (echo of last_word, MSB first)
    reg [3:0] MISO_counter = 4'hE;
    reg last_word_outbit = 1'b0;
    always @(posedge FPGA_clk) begin
        if (CS_falling == 1'b1) begin
            last_word_outbit <= last_word[15];     // bit 15 ready before the first SCK edge
            MISO_counter <= 4'hE;
        end
        else if ((CS_n_sync == 1'b0) && (SCK_falling == 1'b1)) begin
            last_word_outbit <= last_word[MISO_counter];
            MISO_counter <= MISO_counter - 1;      // wraps 0 -> 15 on its own
        end
    end
    
    assign MISO = last_word_outbit;
    assign word_received = last_word;
     
endmodule