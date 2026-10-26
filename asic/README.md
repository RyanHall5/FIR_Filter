# ASIC flow (LibreLane / Sky130)

Same RTL as the FPGA build, so the PPA comparison is fair. The only difference is
`asic/rtl/coef_rom.v`, a generated, synthesizable version of `fpga/rtl/coef_rom.v`
(the FPGA one loads its tables with `$readmemh`, which an ASIC flow cannot build).

AI note: files in this folder were written by Claude (Anthropic).

1. `python asic/scripts/gen_coef_rom.py`   (re-run if the coefficient hex files change)
2. `python asic/scripts/run_asic_ppa.py`   (period sweep + `matlab/data/ppa_reports/asic/asic_ppa_summary.csv`)

Add a new architecture by creating `asic/<name>/config.json` and running with `--design <name>`.
Power comes from OpenSTA's default switching activity, not a simulation, so compare
power only against other ASIC runs, and quote FPGA and ASIC results as ratios to the serial MAC.
