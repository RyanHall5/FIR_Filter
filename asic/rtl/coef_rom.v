//****************************************************
// GENERATED FILE - do not edit. Run asic/scripts/gen_coef_rom.py
// Source      : matlab/data/vectors/coef_ch1.hex, coef_ch2.hex, coef_ch3.hex
// AI note     : generator and this ROM style were written by Claude (Anthropic).
//
// Synthesizable replacement for fpga/rtl/coef_rom.v (ASIC flow only). Same module
// name, parameters, ports and timing: LANES read ports packed into tap_out_flat,
// lane i returns tap (tap_index*LANES + i), registered output, one-clock latency.
// Coefficients are constants in a case table, so synthesis builds them as logic.
// Taps above 58 (padding) and ch_select = 0 read as 0, like the FPGA version.
//****************************************************
module coef_rom #(
    parameter COEF_WIDTH = 16,
    parameter TAP_COUNT = 59,
    parameter LANES = 1
)(
    input wire  clk,                                 // Rising edge enabled clock
    input wire  [1:0] ch_select,                     // Select Channel 1/2/3 (0 = zero output)
    input wire  [$clog2(TAP_COUNT)-1:0] tap_index,   // Step number
    output wire [LANES*COEF_WIDTH-1:0] tap_out_flat  // lane i at [i*COEF_WIDTH +: COEF_WIDTH]
);

    localparam IDX_W = 6;   // bits of a tap index for the 59-entry tables

    // Coefficient lookup, one table per channel (combinational)
    function [COEF_WIDTH-1:0] rom_lookup;
        input [1:0]       ch;
        input [IDX_W-1:0] idx;
        begin
            case ({ch, idx})
                {2'd1, 6'd0}: rom_lookup = 16'h0000;
                {2'd1, 6'd1}: rom_lookup = 16'h0000;
                {2'd1, 6'd2}: rom_lookup = 16'h003D;
                {2'd1, 6'd3}: rom_lookup = 16'h0038;
                {2'd1, 6'd4}: rom_lookup = 16'h0002;
                {2'd1, 6'd5}: rom_lookup = 16'hFF89;
                {2'd1, 6'd6}: rom_lookup = 16'hFEFE;
                {2'd1, 6'd7}: rom_lookup = 16'hFEBA;
                {2'd1, 6'd8}: rom_lookup = 16'hFEFA;
                {2'd1, 6'd9}: rom_lookup = 16'hFFA9;
                {2'd1, 6'd10}: rom_lookup = 16'h005D;
                {2'd1, 6'd11}: rom_lookup = 16'h009D;
                {2'd1, 6'd12}: rom_lookup = 16'h003E;
                {2'd1, 6'd13}: rom_lookup = 16'hFF93;
                {2'd1, 6'd14}: rom_lookup = 16'hFF32;
                {2'd1, 6'd15}: rom_lookup = 16'hFF7E;
                {2'd1, 6'd16}: rom_lookup = 16'h0045;
                {2'd1, 6'd17}: rom_lookup = 16'h00E5;
                {2'd1, 6'd18}: rom_lookup = 16'h00C6;
                {2'd1, 6'd19}: rom_lookup = 16'hFFEE;
                {2'd1, 6'd20}: rom_lookup = 16'hFF0A;
                {2'd1, 6'd21}: rom_lookup = 16'hFEE9;
                {2'd1, 6'd22}: rom_lookup = 16'hFFC3;
                {2'd1, 6'd23}: rom_lookup = 16'h00F0;
                {2'd1, 6'd24}: rom_lookup = 16'h0169;
                {2'd1, 6'd25}: rom_lookup = 16'h00A7;
                {2'd1, 6'd26}: rom_lookup = 16'hFF33;
                {2'd1, 6'd27}: rom_lookup = 16'hFE4A;
                {2'd1, 6'd28}: rom_lookup = 16'hFED4;
                {2'd1, 6'd29}: rom_lookup = 16'h0082;
                {2'd1, 6'd30}: rom_lookup = 16'h01F1;
                {2'd1, 6'd31}: rom_lookup = 16'h01C7;
                {2'd1, 6'd32}: rom_lookup = 16'hFFF6;
                {2'd1, 6'd33}: rom_lookup = 16'hFDF1;
                {2'd1, 6'd34}: rom_lookup = 16'hFD8B;
                {2'd1, 6'd35}: rom_lookup = 16'hFF5A;
                {2'd1, 6'd36}: rom_lookup = 16'h0202;
                {2'd1, 6'd37}: rom_lookup = 16'h032D;
                {2'd1, 6'd38}: rom_lookup = 16'h0194;
                {2'd1, 6'd39}: rom_lookup = 16'hFE49;
                {2'd1, 6'd40}: rom_lookup = 16'hFC18;
                {2'd1, 6'd41}: rom_lookup = 16'hFD33;
                {2'd1, 6'd42}: rom_lookup = 16'h0119;
                {2'd1, 6'd43}: rom_lookup = 16'h049C;
                {2'd1, 6'd44}: rom_lookup = 16'h0467;
                {2'd1, 6'd45}: rom_lookup = 16'h0001;
                {2'd1, 6'd46}: rom_lookup = 16'hFAC0;
                {2'd1, 6'd47}: rom_lookup = 16'hF96C;
                {2'd1, 6'd48}: rom_lookup = 16'hFE1F;
                {2'd1, 6'd49}: rom_lookup = 16'h05CA;
                {2'd1, 6'd50}: rom_lookup = 16'h09D7;
                {2'd1, 6'd51}: rom_lookup = 16'h0550;
                {2'd1, 6'd52}: rom_lookup = 16'hF9CD;
                {2'd1, 6'd53}: rom_lookup = 16'hEFFF;
                {2'd1, 6'd54}: rom_lookup = 16'hF292;
                {2'd1, 6'd55}: rom_lookup = 16'h0675;
                {2'd1, 6'd56}: rom_lookup = 16'h2606;
                {2'd1, 6'd57}: rom_lookup = 16'h430B;
                {2'd1, 6'd58}: rom_lookup = 16'h4ECA;
                {2'd2, 6'd0}: rom_lookup = 16'h0010;
                {2'd2, 6'd1}: rom_lookup = 16'hFFB9;
                {2'd2, 6'd2}: rom_lookup = 16'hFFCA;
                {2'd2, 6'd3}: rom_lookup = 16'h004F;
                {2'd2, 6'd4}: rom_lookup = 16'h004E;
                {2'd2, 6'd5}: rom_lookup = 16'hFFE0;
                {2'd2, 6'd6}: rom_lookup = 16'hFFF5;
                {2'd2, 6'd7}: rom_lookup = 16'hFFD2;
                {2'd2, 6'd8}: rom_lookup = 16'hFF46;
                {2'd2, 6'd9}: rom_lookup = 16'h0037;
                {2'd2, 6'd10}: rom_lookup = 16'h019A;
                {2'd2, 6'd11}: rom_lookup = 16'h002F;
                {2'd2, 6'd12}: rom_lookup = 16'hFE2C;
                {2'd2, 6'd13}: rom_lookup = 16'hFF6B;
                {2'd2, 6'd14}: rom_lookup = 16'h010A;
                {2'd2, 6'd15}: rom_lookup = 16'h0040;
                {2'd2, 6'd16}: rom_lookup = 16'h0031;
                {2'd2, 6'd17}: rom_lookup = 16'h00E5;
                {2'd2, 6'd18}: rom_lookup = 16'hFF31;
                {2'd2, 6'd19}: rom_lookup = 16'hFE27;
                {2'd2, 6'd20}: rom_lookup = 16'h0073;
                {2'd2, 6'd21}: rom_lookup = 16'h0154;
                {2'd2, 6'd22}: rom_lookup = 16'h0007;
                {2'd2, 6'd23}: rom_lookup = 16'h00B1;
                {2'd2, 6'd24}: rom_lookup = 16'h0075;
                {2'd2, 6'd25}: rom_lookup = 16'hFD71;
                {2'd2, 6'd26}: rom_lookup = 16'hFE62;
                {2'd2, 6'd27}: rom_lookup = 16'h027F;
                {2'd2, 6'd28}: rom_lookup = 16'h01AC;
                {2'd2, 6'd29}: rom_lookup = 16'hFF60;
                {2'd2, 6'd30}: rom_lookup = 16'h009F;
                {2'd2, 6'd31}: rom_lookup = 16'hFF0B;
                {2'd2, 6'd32}: rom_lookup = 16'hFC16;
                {2'd2, 6'd33}: rom_lookup = 16'h00A2;
                {2'd2, 6'd34}: rom_lookup = 16'h04EA;
                {2'd2, 6'd35}: rom_lookup = 16'h0083;
                {2'd2, 6'd36}: rom_lookup = 16'hFE31;
                {2'd2, 6'd37}: rom_lookup = 16'h004D;
                {2'd2, 6'd38}: rom_lookup = 16'hFCD2;
                {2'd2, 6'd39}: rom_lookup = 16'hFC39;
                {2'd2, 6'd40}: rom_lookup = 16'h0585;
                {2'd2, 6'd41}: rom_lookup = 16'h065F;
                {2'd2, 6'd42}: rom_lookup = 16'hFCB6;
                {2'd2, 6'd43}: rom_lookup = 16'hFCC0;
                {2'd2, 6'd44}: rom_lookup = 16'hFFC9;
                {2'd2, 6'd45}: rom_lookup = 16'hFA40;
                {2'd2, 6'd46}: rom_lookup = 16'hFFFF;
                {2'd2, 6'd47}: rom_lookup = 16'h0DC2;
                {2'd2, 6'd48}: rom_lookup = 16'h03E4;
                {2'd2, 6'd49}: rom_lookup = 16'hF3E1;
                {2'd2, 6'd50}: rom_lookup = 16'hFC17;
                {2'd2, 6'd51}: rom_lookup = 16'hFF51;
                {2'd2, 6'd52}: rom_lookup = 16'hF73F;
                {2'd2, 6'd53}: rom_lookup = 16'h0FAB;
                {2'd2, 6'd54}: rom_lookup = 16'h2254;
                {2'd2, 6'd55}: rom_lookup = 16'hEBE4;
                {2'd2, 6'd56}: rom_lookup = 16'hC318;
                {2'd2, 6'd57}: rom_lookup = 16'h091F;
                {2'd2, 6'd58}: rom_lookup = 16'h4845;
                {2'd3, 6'd0}: rom_lookup = 16'h0000;
                {2'd3, 6'd1}: rom_lookup = 16'h0000;
                {2'd3, 6'd2}: rom_lookup = 16'h000A;
                {2'd3, 6'd3}: rom_lookup = 16'hFF67;
                {2'd3, 6'd4}: rom_lookup = 16'h012C;
                {2'd3, 6'd5}: rom_lookup = 16'hFEA6;
                {2'd3, 6'd6}: rom_lookup = 16'h00BF;
                {2'd3, 6'd7}: rom_lookup = 16'h003D;
                {2'd3, 6'd8}: rom_lookup = 16'hFF46;
                {2'd3, 6'd9}: rom_lookup = 16'h004A;
                {2'd3, 6'd10}: rom_lookup = 16'h007E;
                {2'd3, 6'd11}: rom_lookup = 16'hFF61;
                {2'd3, 6'd12}: rom_lookup = 16'hFFE9;
                {2'd3, 6'd13}: rom_lookup = 16'h00BC;
                {2'd3, 6'd14}: rom_lookup = 16'hFF94;
                {2'd3, 6'd15}: rom_lookup = 16'hFF7C;
                {2'd3, 6'd16}: rom_lookup = 16'h00D6;
                {2'd3, 6'd17}: rom_lookup = 16'hFFFA;
                {2'd3, 6'd18}: rom_lookup = 16'hFF13;
                {2'd3, 6'd19}: rom_lookup = 16'h00B2;
                {2'd3, 6'd20}: rom_lookup = 16'h008B;
                {2'd3, 6'd21}: rom_lookup = 16'hFED2;
                {2'd3, 6'd22}: rom_lookup = 16'h003D;
                {2'd3, 6'd23}: rom_lookup = 16'h0129;
                {2'd3, 6'd24}: rom_lookup = 16'hFEE5;
                {2'd3, 6'd25}: rom_lookup = 16'hFF7D;
                {2'd3, 6'd26}: rom_lookup = 16'h019E;
                {2'd3, 6'd27}: rom_lookup = 16'hFF69;
                {2'd3, 6'd28}: rom_lookup = 16'hFE99;
                {2'd3, 6'd29}: rom_lookup = 16'h01AD;
                {2'd3, 6'd30}: rom_lookup = 16'h0060;
                {2'd3, 6'd31}: rom_lookup = 16'hFDD6;
                {2'd3, 6'd32}: rom_lookup = 16'h0122;
                {2'd3, 6'd33}: rom_lookup = 16'h01A2;
                {2'd3, 6'd34}: rom_lookup = 16'hFD8B;
                {2'd3, 6'd35}: rom_lookup = 16'hFFEA;
                {2'd3, 6'd36}: rom_lookup = 16'h02DB;
                {2'd3, 6'd37}: rom_lookup = 16'hFE0A;
                {2'd3, 6'd38}: rom_lookup = 16'hFE27;
                {2'd3, 6'd39}: rom_lookup = 16'h0394;
                {2'd3, 6'd40}: rom_lookup = 16'hFF8A;
                {2'd3, 6'd41}: rom_lookup = 16'hFC36;
                {2'd3, 6'd42}: rom_lookup = 16'h0349;
                {2'd3, 6'd43}: rom_lookup = 16'h0207;
                {2'd3, 6'd44}: rom_lookup = 16'hFAAB;
                {2'd3, 6'd45}: rom_lookup = 16'h0183;
                {2'd3, 6'd46}: rom_lookup = 16'h0540;
                {2'd3, 6'd47}: rom_lookup = 16'hFA4A;
                {2'd3, 6'd48}: rom_lookup = 16'hFDD6;
                {2'd3, 6'd49}: rom_lookup = 16'h08BB;
                {2'd3, 6'd50}: rom_lookup = 16'hFC1B;
                {2'd3, 6'd51}: rom_lookup = 16'hF7A1;
                {2'd3, 6'd52}: rom_lookup = 16'h0BD9;
                {2'd3, 6'd53}: rom_lookup = 16'h0240;
                {2'd3, 6'd54}: rom_lookup = 16'hEC2E;
                {2'd3, 6'd55}: rom_lookup = 16'h0E03;
                {2'd3, 6'd56}: rom_lookup = 16'h19B6;
                {2'd3, 6'd57}: rom_lookup = 16'hB345;
                {2'd3, 6'd58}: rom_lookup = 16'h641F;
                default: rom_lookup = 16'h0;
            endcase
        end
    endfunction

    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin : lane
            wire [31:0] tap = tap_index*LANES + i;     // this lane's tap
            reg  [COEF_WIDTH-1:0] lane_q;               // this lane's output register

            // Registered output (one-clock latency); padded taps read as 0
            always @(posedge clk) begin
                if (tap < TAP_COUNT)
                    lane_q <= rom_lookup(ch_select, tap[IDX_W-1:0]);
                else
                    lane_q <= {COEF_WIDTH{1'b0}};
            end

            assign tap_out_flat[i*COEF_WIDTH +: COEF_WIDTH] = lane_q;
        end
    endgenerate
endmodule
