//****************************************************
// Company : Rochester Institute of Technology (RIT )
// Engineer : Ryan Hall (rah3587@rit.edu)
//
// Create Date : 10/6/26
// Design Name : sample_buffer
// Module Name : sample_buffer
// Project Name : FIR_Filter
// Target Devices : Basys3
//
// Description : Circular buffer of the last BUFFER_COUNT input samples. Given a tap
// index k it returns two samples at once, for the folded FIR pre-add:
//     sample1 = x[n-k]                    ("delay k")
//     sample2 = x[n-(BUFFER_COUNT-1-k)]   ("delay BUFFER_COUNT-1-k")
// where x[n] is the newest sample. Delays that reach back before the first write
// return 0, matching the golden model's all-zero starting history.
//
// Timing: both outputs are registered, so they show the result one clock after k is
// presented. A sample written on a given clock edge can be read starting with the
// next edge (a read in the same cycle as the write sees the old data).
// k must be in 0 .. BUFFER_COUNT-1.
//****************************************************
module sample_buffer #(
    parameter BUFFER_COUNT = 117,
    parameter DATA_WIDTH   = 16
)(
    input  wire clk,                                  // Rising edge enabled clock
    input  wire rst,                                  // Synchronous reset (clears pointer and count)
    input  wire we,                                   // Write enable: store wd as the newest sample
    input  wire signed [DATA_WIDTH-1:0] wd,           // Write data
    input  wire [$clog2(BUFFER_COUNT)-1:0] k,         // Tap index / delay of sample1
    output reg  signed [DATA_WIDTH-1:0] sample1,      // Delay k
    output reg  signed [DATA_WIDTH-1:0] sample2       // Delay BUFFER_COUNT-1-k
);

    localparam ADDR_BITS = $clog2(BUFFER_COUNT);       // bits to index 0..BUFFER_COUNT-1
    localparam CNT_BITS  = $clog2(BUFFER_COUNT + 1);   // counter must reach BUFFER_COUNT itself
    localparam LAST_IDX  = BUFFER_COUNT - 1;

    reg [ADDR_BITS-1:0] IN_PTR;                        // Where the next input goes (newest is IN_PTR-1)
    reg [CNT_BITS-1:0]  numReceived;                   // Samples written since reset, saturates at BUFFER_COUNT

    reg signed [DATA_WIDTH-1:0] buffer [0:BUFFER_COUNT-1];   // Data storage (no reset needed: see valid1/valid2)

    // Write pointer and fill counter
    always @(posedge clk) begin
        if (rst) begin
            IN_PTR      <= {ADDR_BITS{1'b0}};
            numReceived <= {CNT_BITS{1'b0}};
        end else if (we) begin
            if (IN_PTR == LAST_IDX) 
                IN_PTR <= {ADDR_BITS{1'b0}};
            else                    
                IN_PTR <= IN_PTR + 1'b1;
                
            if (numReceived < BUFFER_COUNT) 
                numReceived <= numReceived + 1'b1;
        end
    end

    // Memory write (kept separate, with no reset, so it can map to RAM)
    always @(posedge clk) begin
        if (we) 
            buffer[IN_PTR] <= wd;
    end

    // Read addresses, computed so they never go below zero:
    //   delay d lives at (IN_PTR - 1 - d) mod BUFFER_COUNT
    //   delay k              -> IN_PTR + BUFFER_COUNT - 1 - k, then wrap
    //   delay LAST_IDX - k   -> IN_PTR + k, then wrap
    reg [ADDR_BITS:0] addr1, addr2;                    // one bit wider than an address (sum can reach 2N-2)
    always @(*) begin
        addr1 = IN_PTR + BUFFER_COUNT - 1 - k;
        if (addr1 >= BUFFER_COUNT) 
            addr1 = addr1 - BUFFER_COUNT;

        addr2 = IN_PTR + k;
        if (addr2 >= BUFFER_COUNT) 
            addr2 = addr2 - BUFFER_COUNT;
    end

    // A delay is valid only if that many samples have actually been written
    wire valid1 = (k < numReceived);
    wire valid2 = ((LAST_IDX - k) < numReceived);

    // Registered reads; zero for delays older than the first sample
    always @(posedge clk) begin
        if (rst) begin
            sample1 <= {DATA_WIDTH{1'b0}};
            sample2 <= {DATA_WIDTH{1'b0}};
        end else begin
            sample1 <= valid1 ? buffer[addr1[ADDR_BITS-1:0]] : {DATA_WIDTH{1'b0}};
            sample2 <= valid2 ? buffer[addr2[ADDR_BITS-1:0]] : {DATA_WIDTH{1'b0}};
        end
    end

endmodule