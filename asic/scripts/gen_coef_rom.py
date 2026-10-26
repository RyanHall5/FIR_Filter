#!/usr/bin/env python3
"""
gen_coef_rom.py -- generate a synthesizable coef_rom.v for the ASIC (LibreLane) flow.

AI note: written by Claude (Anthropic) for Ryan Hall's FIR_Filter project.

Why: fpga/rtl/coef_rom.v loads its tables with $readmemh in an initial block. That
works in Vivado (and simulation) but Yosys/LibreLane cannot turn it into hardware, so
the ASIC build needs the coefficients written into the RTL as constants. This reads the
same MATLAB-generated hex files, so the FPGA and ASIC builds use identical coefficients.

The generated module has the SAME name, ports and timing as fpga/rtl/coef_rom.v
(registered output, one-clock read latency), so FIR_Core_MAC.v is used unchanged.

Usage (from the repo root):
    python asic/scripts/gen_coef_rom.py
    python asic/scripts/gen_coef_rom.py --vectors matlab/data/vectors --out asic/rtl/coef_rom.v
Re-run it whenever the coefficient hex files change.
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
    idx_w = max(1, (n - 1).bit_length())
    W = args.width
    hexd = (W + 3) // 4

    L = []
    L.append("//****************************************************")
    L.append("// GENERATED FILE - do not edit. Run asic/scripts/gen_coef_rom.py")
    L.append("// Source      : matlab/data/vectors/coef_ch1.hex, coef_ch2.hex, coef_ch3.hex")
    L.append("// AI note     : generator and this ROM style were written by Claude (Anthropic).")
    L.append("//")
    L.append("// Synthesizable replacement for fpga/rtl/coef_rom.v (ASIC flow only). Same")
    L.append("// module name, ports and timing: registered output, one-clock read latency.")
    L.append("// Coefficients are constants in a case table, so synthesis builds them as logic.")
    L.append(f"// Entries above {n-1} (and ch_select = 0) read as 0, like the FPGA version's default.")
    L.append("//****************************************************")
    L.append("module coef_rom #(")
    L.append(f"    parameter COEF_WIDTH = {W},")
    L.append(f"    parameter TAP_COUNT = {n}")
    L.append(")(")
    L.append("    input wire  clk,                  // Rising edge enabled clock")
    L.append("    input wire  [1:0] ch_select,      // Select Channel 1/2/3 (0 = zero output)")
    L.append("    input wire  [$clog2(TAP_COUNT)-1:0] tap_index,  // Select tap")
    L.append("    output reg signed [COEF_WIDTH-1:0] tap_out      // Output tap value")
    L.append(");")
    L.append("")
    L.append("    // Combinational lookup, one table per channel")
    L.append("    reg signed [COEF_WIDTH-1:0] rom_value;")
    L.append("")
    L.append("    always @(*) begin")
    L.append("        case ({ch_select, tap_index})")
    for c, t in enumerate(tables, 1):
        for i, v in enumerate(t):
            L.append(f"            {{2'd{c}, {idx_w}'d{i}}}: rom_value = {W}'h{v:0{hexd}X};")
    L.append(f"            default: rom_value = {W}'h0;")
    L.append("        endcase")
    L.append("    end")
    L.append("")
    L.append("    // Registered output (one-clock latency, matches the FPGA version)")
    L.append("    always @(posedge clk) begin")
    L.append("        tap_out <= rom_value;")
    L.append("    end")
    L.append("endmodule")
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(L) + "\n")
    print(f"wrote {out}: {n} taps x {NCH} channels, {W}-bit")

if __name__ == "__main__":
    main()
