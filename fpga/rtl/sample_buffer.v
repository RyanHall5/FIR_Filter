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
// AI note     : Comments, code organization were done by Claude.
//
// Description : Circular buffer of the last BUFFER_COUNT input samples. Given a tap
//               index k it returns two samples at once, for the folded FIR pre-add:
//                   sample1 = x[n-k]                    ("delay k")
//                   sample2 = x[n-(BUFFER_COUNT-1-k)]   ("delay BUFFER_COUNT-1-k")
//               where x[n] is the newest sample. Delays that reach back before the
//               first write return 0, matching the golden model's all-zero history.
//
// Timing      : Both outputs are registered, so they show the result one clock after k
//               is presented. A sample written on a given clock edge can be read
//               starting with the next edge (a read in the same cycle as the write
//               sees the old data).
//
// Usage       : k must be in 0 .. BUFFER_COUNT-1. FIR_Core_MAC only drives
//               0 .. TAP_COUNT-1 (= (BUFFER_COUNT-1)/2), where the two delays meet at
//               the centre tap. A core that doesn't fold the filter can ignore sample2.
//
// Reset       : Only the pointer, the fill counter and the output registers are reset.
//               The storage array is not, which keeps it free of reset logic: delays
//               older than the first sample are masked to 0 by valid1/valid2 instead.
//****************************************************
module sample_buffer #(
    parameter BUFFER_COUNT = 117,                     // filter length (number of samples kept)
    parameter DATA_WIDTH   = 16                       // sample width (bits)
)(
    input  wire clk,                                  // Rising edge enabled clock
    input  wire rst,                                  // Synchronous reset (clears pointer, count and outputs)
    input  wire we,                                   // Write enable: store wd as the newest sample
    input  wire signed [DATA_WIDTH-1:0] wd,           // Write data
    input  wire [$clog2(BUFFER_COUNT)-1:0] k,         // Tap index / delay of sample1
    output reg  signed [DATA_WIDTH-1:0] sample1,      // Delay k
    output reg  signed [DATA_WIDTH-1:0] sample2       // Delay BUFFER_COUNT-1-k
);

    //====================================================
    // Local parameters
    //====================================================
    localparam ADDR_BITS = $clog2(BUFFER_COUNT);       // bits to index 0..BUFFER_COUNT-1
    localparam CNT_BITS  = $clog2(BUFFER_COUNT + 1);   // counter must reach BUFFER_COUNT itself
    localparam LAST_IDX  = BUFFER_COUNT - 1;

    //====================================================
    // Signal declarations
    //====================================================
    reg [ADDR_BITS-1:0] in_ptr;                        // Where the next input goes (newest is in_ptr-1)
    reg [CNT_BITS-1:0]  numReceived;                   // Samples written since reset, saturates at BUFFER_COUNT
    reg signed [DATA_WIDTH-1:0] buffer [0:BUFFER_COUNT-1];   // Data storage (not reset: see valid1/valid2)

    reg [ADDR_BITS:0] addr1, addr2;                    // Read addresses, one bit wider than an address (sum can reach 2N-2)
    wire valid1;                                       // delay k has been written since reset
    wire valid2;                                       // delay LAST_IDX-k has been written since reset

    //====================================================
    // Write side
    //====================================================

    // in_ptr process: advances on each write, wraps from the last slot back to 0
    always @(posedge clk) begin
        if (rst)
            in_ptr <= {ADDR_BITS{1'b0}};
        else if (we) begin
            if (in_ptr == LAST_IDX)
                in_ptr <= {ADDR_BITS{1'b0}};
            else
                in_ptr <= in_ptr + 1'b1;
        end
    end

    // numReceived process: counts writes since reset and stops at BUFFER_COUNT
    // (once full, every delay is real data and valid1/valid2 stay high)
    always @(posedge clk) begin
        if (rst)
            numReceived <= {CNT_BITS{1'b0}};
        else if (we && numReceived < BUFFER_COUNT)
            numReceived <= numReceived + 1'b1;
    end

    // Memory write: kept as its own process, with no reset, so it can map to RAM
    always @(posedge clk) begin
        if (we)
            buffer[in_ptr] <= wd;
    end

    //====================================================
    // Read side
    //====================================================

    // Read addresses. Delay d lives at (in_ptr - 1 - d) mod BUFFER_COUNT; the
    // expressions below are arranged so they never go below zero:
    //   delay k              -> in_ptr + BUFFER_COUNT - 1 - k, then wrap
    //   delay LAST_IDX - k   -> in_ptr + k, then wrap
    // Both sums are below 2*BUFFER_COUNT, so one conditional subtract is enough to wrap.
    always @(*) begin
        addr1 = in_ptr + BUFFER_COUNT - 1 - k;
        if (addr1 >= BUFFER_COUNT)
            addr1 = addr1 - BUFFER_COUNT;

        addr2 = in_ptr + k;
        if (addr2 >= BUFFER_COUNT)
            addr2 = addr2 - BUFFER_COUNT;
    end

    // A delay is valid only if that many samples have actually been written.
    // This replaces clearing the storage array on reset.
    assign valid1 = (k < numReceived);
    assign valid2 = ((LAST_IDX - k) < numReceived);

    // sample1 process: registered read, 0 for delays older than the first sample
    always @(posedge clk) begin
        if (rst)
            sample1 <= {DATA_WIDTH{1'b0}};
        else
            sample1 <= valid1 ? buffer[addr1[ADDR_BITS-1:0]] : {DATA_WIDTH{1'b0}};
    end

    // sample2 process: same, for the mirrored delay
    always @(posedge clk) begin
        if (rst)
            sample2 <= {DATA_WIDTH{1'b0}};
        else
            sample2 <= valid2 ? buffer[addr2[ADDR_BITS-1:0]] : {DATA_WIDTH{1'b0}};
    end

endmodule