#!/usr/bin/env python3
"""
gen_coef_rom.py -- generate a synthesizable coef_rom.v for the ASIC (LibreLane) flow.

AI note: written by Claude (Anthropic) for Ryan Hall's FIR_Filter project.

Why: fpga/rtl/coef_rom.v loads its tables with $readmemh in an initial block. That
works in Vivado (and simulation) but Yosys/LibreLane cannot turn it into hardware, so
the ASIC build needs the coefficients written into the RTL as constants. This reads the
same MATLAB-generated hex files, so the FPGA and ASIC builds use identical coefficients.

The generated module has the SAME name, parameters, ports and timing as
fpga/rtl/coef_rom.v, so FIR_Core_MAC.v is used unchanged:
  - parameters COEF_WIDTH, TAP_COUNT, LANES
  - tap_index is the step number; lane i returns tap (tap_index*LANES + i)
  - tap_out_flat packs the lanes: lane i is bits [i*COEF_WIDTH +: COEF_WIDTH]
  - taps past TAP_COUNT-1 (padding) and ch_select = 0 read as 0
  - registered output, one-clock read latency

Usage (from the repo root):
    python asic/scripts/gen_coef_rom.py
    python asic/scripts/gen_coef_rom.py --vectors matlab/data/vectors --out asic/rtl/coef_rom.v
Re-run it whenever the coefficient hex files change. LANES is chosen by whoever
instantiates the ROM (the core passes its own LANES), so one generated file serves
every lane count.
"""
import argparse
from pathlib import Path

NCH = 3

def read_hex(path):
    vals = [ln.strip() for ln in path.read_text().splitlines() if ln.strip()]
    return [int(v, 16) for v in vals]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--vectors", default="matlab/data/vectors")
    ap.add_argument("--out", default="asic/rtl/coef_rom.v")
    ap.add_argument("--width", type=int, default=16)
    args = ap.parse_args()

    vec = Path(args.vectors)
    tables = [read_hex(vec / f"coef_ch{c}.hex") for c in range(1, NCH + 1)]
    n = len(tables[0])
    for c, t in enumerate(tables, 1):
        if len(t) != n:
            raise SystemExit(f"coef_ch{c}.hex has {len(t)} entries, expected {n}")
        if any(v >= (1 << args.width) for v in t):
            raise SystemExit(f"coef_ch{c}.hex has a value wider than {args.width} bits")
    idx_w = max(1, (n - 1).bit_length())       # equals $clog2(TAP_COUNT) for TAP_COUNT = n
    W = args.width
    hexd = (W + 3) // 4

    L = []
    L.append("//****************************************************")
    L.append("// GENERATED FILE - do not edit. Run asic/scripts/gen_coef_rom.py")
    L.append("// Source      : matlab/data/vectors/coef_ch1.hex, coef_ch2.hex, coef_ch3.hex")
    L.append("// AI note     : generator and this ROM style were written by Claude (Anthropic).")
    L.append("//")
    L.append("// Synthesizable replacement for fpga/rtl/coef_rom.v (ASIC flow only). Same module")
    L.append("// name, parameters, ports and timing: LANES read ports packed into tap_out_flat,")
    L.append("// lane i returns tap (tap_index*LANES + i), registered output, one-clock latency.")
    L.append("// Coefficients are constants in a case table, so synthesis builds them as logic.")
    L.append(f"// Taps above {n-1} (padding) and ch_select = 0 read as 0, like the FPGA version.")
    L.append("//****************************************************")
    L.append("module coef_rom #(")
    L.append(f"    parameter COEF_WIDTH = {W},")
    L.append(f"    parameter TAP_COUNT = {n},")
    L.append("    parameter LANES = 1")
    L.append(")(")
    L.append("    input wire  clk,                                 // Rising edge enabled clock")
    L.append("    input wire  [1:0] ch_select,                     // Select Channel 1/2/3 (0 = zero output)")
    L.append("    input wire  [$clog2(TAP_COUNT)-1:0] tap_index,   // Step number")
    L.append("    output wire [LANES*COEF_WIDTH-1:0] tap_out_flat  // lane i at [i*COEF_WIDTH +: COEF_WIDTH]")
    L.append(");")
    L.append("")
    L.append(f"    localparam IDX_W = {idx_w};   // bits of a tap index for the {n}-entry tables")
    L.append("")
    L.append("    // Coefficient lookup, one table per channel (combinational)")
    L.append("    function [COEF_WIDTH-1:0] rom_lookup;")
    L.append("        input [1:0]       ch;")
    L.append("        input [IDX_W-1:0] idx;")
    L.append("        begin")
    L.append("            case ({ch, idx})")
    for c, t in enumerate(tables, 1):
        for i, v in enumerate(t):
            L.append(f"                {{2'd{c}, {idx_w}'d{i}}}: rom_lookup = {W}'h{v:0{hexd}X};")
    L.append(f"                default: rom_lookup = {W}'h0;")
    L.append("            endcase")
    L.append("        end")
    L.append("    endfunction")
    L.append("")
    L.append("    genvar i;")
    L.append("    generate")
    L.append("        for (i = 0; i < LANES; i = i + 1) begin : lane")
    L.append("            wire [31:0] tap = tap_index*LANES + i;     // this lane's tap")
    L.append("            reg  [COEF_WIDTH-1:0] lane_q;               // this lane's output register")
    L.append("")
    L.append("            // Registered output (one-clock latency); padded taps read as 0")
    L.append("            always @(posedge clk) begin")
    L.append("                if (tap < TAP_COUNT)")
    L.append("                    lane_q <= rom_lookup(ch_select, tap[IDX_W-1:0]);")
    L.append("                else")
    L.append("                    lane_q <= {COEF_WIDTH{1'b0}};")
    L.append("            end")
    L.append("")
    L.append("            assign tap_out_flat[i*COEF_WIDTH +: COEF_WIDTH] = lane_q;")
    L.append("        end")
    L.append("    endgenerate")
    L.append("endmodule")
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(L) + "\n")
    print(f"wrote {out}: {n} taps x {NCH} channels, {W}-bit, LANES chosen at instantiation")

if __name__ == "__main__":
    main()
