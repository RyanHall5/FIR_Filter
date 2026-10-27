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
    parameter DATA_WIDTH   = 16,                      // sample width (bits)
    parameter LANES        = 1
)(
    input  wire clk,                                  // Rising edge enabled clock
    input  wire rst,                                  // Synchronous reset (clears pointer, count and outputs)
    input  wire we,                                   // Write enable: store wd as the newest sample
    input  wire signed [DATA_WIDTH-1:0] wd,           // Write data
    input  wire [$clog2(BUFFER_COUNT)-1:0] k,         // Tap index / delay of sample1
    output wire [LANES*DATA_WIDTH-1:0] sample1_flat,      // Delay k
    output wire [LANES*DATA_WIDTH-1:0] sample2_flat       // Delay BUFFER_COUNT-1-k
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

    // sample process
    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin : lane

            // this lane's tap = its delay for sample1
            wire [ADDR_BITS-1:0] kj = k*LANES + i;

            // ---- sample1 read path ----
            reg  [ADDR_BITS:0] addr1;                  // one bit wider: sum can reach 2N-2
            wire               valid1 = (kj < numReceived);

            always @(*) begin
                addr1 = in_ptr + BUFFER_COUNT - 1 - kj;
                if (addr1 >= BUFFER_COUNT)
                    addr1 = addr1 - BUFFER_COUNT;
            end

            reg signed [DATA_WIDTH-1:0] sample1_lane_i;     // this lane's output register

            always @(posedge clk) begin
                if (rst)
                    sample1_lane_i <= {DATA_WIDTH{1'b0}};
                else
                    sample1_lane_i <= valid1 ? buffer[addr1[ADDR_BITS-1:0]] : {DATA_WIDTH{1'b0}};
            end

            assign sample1_flat[i*DATA_WIDTH +: DATA_WIDTH] = sample1_lane_i;


            // ---- sample2 read path ----
            reg  [ADDR_BITS:0] addr2;                  // one bit wider: sum can reach 2N-2
            wire               valid2 = ((LAST_IDX-kj) < numReceived);

            always @(*) begin
                addr2 = in_ptr + kj;
                if (addr2 >= BUFFER_COUNT)
                    addr2 = addr2 - BUFFER_COUNT;
            end

            reg signed [DATA_WIDTH-1:0] sample2_lane_i;     // this lane's output register

            always @(posedge clk) begin
                if (rst)
                    sample2_lane_i <= {DATA_WIDTH{1'b0}};
                else
                    sample2_lane_i <= valid2 ? buffer[addr2[ADDR_BITS-1:0]] : {DATA_WIDTH{1'b0}};
            end

            assign sample2_flat[i*DATA_WIDTH +: DATA_WIDTH] = sample2_lane_i;
            
        end
    endgenerate

endmodule