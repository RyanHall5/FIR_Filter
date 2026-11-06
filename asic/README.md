# ASIC flow (LibreLane / Sky130)

Same RTL as the FPGA build, so the PPA comparison is fair. The only difference is
`asic/rtl/coef_rom.v`, a generated, synthesizable version of `fpga/rtl/coef_rom.v`
(the FPGA one loads its tables with `$readmemh`, which an ASIC flow cannot build).
It has the same parameters (including `LANES`), ports and timing, and was checked
formally equivalent to the FPGA ROM with Yosys for LANES = 1, 2, 4, 7, 8, 16 and 59.

AI note: files in this folder were written by Claude (Anthropic). The core
(`fpga/rtl/FIR_Core_MAC.v`) and buffer it builds were written by Ryan Hall.

## Folders

- `rtl/coef_rom.v` - generated ROM (do not edit)
- `serial_mac/` - the original serial-core design (keeps its earlier runs)
- `lanes<N>/` - one design per lane count: `fir_lanes<N>.v` (a wrapper that fixes
  `LANES = N`, same ports as the core) and `config.json` (DESIGN_NAME = the wrapper)
- `scripts/` - `gen_coef_rom.py`, `make_lane_designs.py`, `run_asic_ppa.py`

## Running

Run from the repo root, in the nix-shell where `librelane` works:

1. `python3 asic/scripts/gen_coef_rom.py` - re-run if the coefficient hex files change
2. `python3 asic/scripts/make_lane_designs.py` - only to add lane counts (default 1 2 4 8 16;
   e.g. `--lanes 32`). The folders for 1, 2, 4, 8, 16 are already committed.
3. Sweep, e.g.
   - `python3 asic/scripts/run_asic_ppa.py --design lanes1 --periods 40` (regression check
     against serial_mac: should match ~179,700 um2 and ~7.6 mW at 40 ns)
   - `python3 asic/scripts/run_asic_ppa.py --design lanes1 lanes2 lanes4 --periods 40 25`
4. `python3 asic/scripts/run_asic_ppa.py --collect-only` rebuilds the CSV without running anything.

Finished runs are skipped. Every run records the git commit in `runs/<tag>/ppa_meta.json`,
so commit RTL changes before sweeping. The summary
`matlab/data/ppa_reports/asic/asic_ppa_summary.csv` is rebuilt from every design folder
each time (columns include `architecture` and `lanes`), so one design never overwrites another.

## Notes

- Sky130 has no block RAM: the 117-sample buffer is always flip-flops, and every lane adds
  two more 117:1 read multiplexers. A Yosys generic synthesis (not Sky130 cells) gives
  about 10k cells at LANES = 1 rising roughly linearly to 115k at LANES = 16, so expect
  lanes8 and lanes16 to be large and much slower to run than lanes1-4.
- Power comes from OpenSTA's default switching activity, not a simulation, so compare
  power only against other ASIC runs, and quote FPGA and ASIC results as ratios to the serial core.
