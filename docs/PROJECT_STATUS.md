# FIR_Filter: project status and handoff (2026-10-26)

AI note: written by Claude (Anthropic) from the working session, to carry context into new conversations.
Owner: Ryan Hall (RIT EE). Goal: 2 ft x 3 ft (36x24 in, landscape) poster with PPA analysis, results, conclusions.
Deadline: not yet known.

## Preferences (how to work with Ryan)
- He writes his own Verilog to learn it: give critique/outlines for core HDL, write it only if he asks.
  MATLAB, Python/Tcl scripts and glue code are fine for Claude to write.
- One signal per `always` block. AI usage is noted in the header of any file Claude touches.
- Scope rule (his decision): compare only what an individual can actually build: Basys 3 FPGA
  (Artix-7 xc7a35tcpg236-1, 28 nm) and the open Sky130 ASIC flow (LibreLane, 130 nm).
  Predictive PDKs (NanGate45, ASAP7) are NOT used because they cannot be fabricated; mention in a note.

## System
MATLAB 3-channel composite (fs 96 kHz) -> UART (2.25 Mbaud) -> STM32 Nucleo-F446RE -> SPI (mode 0, ~2.8 MHz SCK,
512-word bursts, 16-bit words) -> Basys 3 FPGA -> back. Full loop verified bit-exact on channel 1
(impulse, step, composite). Returned word in slot m is y[m-2] (fixed lag 2, via tx_hold in top.v).
Channels 2 and 3 on hardware and the audio demo (`run_analysis`) are still to do; switches must match `cfg.hw.channel`.

## Design (fpga/rtl)
FIR: 117 taps, folded symmetric, 59 stored coefficients, COEF_W 16, SAMPLE_W 16, SHIFT 16, ACC_W 39.
`FIR_Core_MAC` (Ryan's serial MAC, 1 multiplier, 64-clock latency), `coef_rom`, `sample_buffer`, `spi_slave`, `top`.
Testbench `FIR_Core_Mac_tb.v`: 21 tests, 0 errors. ASIC uses `asic/rtl/coef_rom.v` (generated case-table ROM,
`asic/scripts/gen_coef_rom.py`); same ports/timing, passes the same tests.

## Clock requirements (analysis, not yet all verified on hardware)
SPI return path (MISO settles 2-3 FPGA clocks after SCK falling, must beat the ~178 ns half period) -> FPGA clock >= ~20 MHz
(use 25 MHz or higher). Filter workload needs only ~6 MHz average / ~11 MHz in bursts. Operating window ~20-44 MHz.
Headline operating point: 25 MHz (40 ns). Basys 3 clock is fixed at 100 MHz (MMCM or clock enable needed to run slower).

## Common sweep periods: 40, 30, 25, 20 ns (FPGA also has 10, 8, 6, 5; ASIC also 15, 12, 10)
Compare platforms only at the same period.

## FPGA results (Vivado 2026.1, OOC, vectorless power; matlab/data/ppa_reports/fpga/fpga_ppa_summary.csv, commit 0894986)
serial_mac; WNS ns / timing met / LUT / FF / DSP / BRAM / dynamic mW:
- DSP variant: 40 ns +32.98 yes 153/46/1/1 1 mW; 30 ns +22.93 yes 2 mW; 25 ns +17.93 yes 2 mW; 20 ns +13.00 yes 3 mW;
  10 ns +3.47 yes 6 mW; 8 ns +1.49 yes 7 mW; 6 ns +0.14 yes 161 LUT 9 mW (tightest met, Fmax ~171 MHz);
  5 ns -0.84 NO (tool moved buffer to distributed RAM: 295 LUT, 90 LUT-as-memory, 0 BRAM) 10 mW.
- No-DSP variant: 40/30/25/20 ns all met (WNS +28.7/+18.9/+13.9/+9.5), 472 LUT, 159 FF, 0 DSP, 1 BRAM, 3/4/5/6 mW;
  10 ns +0.50 yes 475 LUT 12 mW (tightest met, Fmax ~105 MHz); 8, 6, 5 ns fail (-0.87, -1.96, -3.04), 497-538 LUT, 16-27 mW.
- Energy per clock (dynamic power x period): DSP ~50-60 pJ/clk, no-DSP ~120-135 pJ/clk (use the 10 ns rows; the CSV rounds
  dynamic power to 1 mW so the 40-20 ns values are +-0.5 mW noise). ASIC is 304.5 pJ/clk (~5x DSP, ~2.5x no-DSP).
- Static power ~0.068 W dominates total FPGA power (dynamic is only 1-3 mW at 25-40 MHz): report dynamic separately.
- Fmax estimate = 1/(period - WNS) drifts with tool effort (DSP 142 MHz at relaxed periods vs 171 at 6 ns): quote from the tightest MET run.
- Area/LUT counts are flat across relaxed periods (153 DSP / 472 no-DSP LUTs); they grow only when timing is tight.

## ASIC results (LibreLane, Sky130, serial_mac, default switching activity)
| period ns | WNS ns | met | std-cell area um2 | power mW | power*period (pJ/clk) |
| 40 | +17.10 | yes | 179,674 | 7.61 | 304.5 |
| 30 | +7.10 | yes | 179,674 | 10.15 | 304.5 |
| 25 | +2.24 | yes | 179,651 | 12.18 | 304.5 |
| 20 | -2.76 | no | 179,651 | 15.22 | 304.5 |
| 15, 12, 10 | -4.05, -3.09, -3.90 | no | ~179,500-184,900 | 20.3, 25.4, 31.7 | |
Critical path ~22.8 ns (Fmax ~43.9 MHz). DRC, LVS, antenna errors all 0. 2067 flops (sample buffer = 1872).
Area breakdown at 40 ns: sequential 43,966; combinational 86,015; timing-repair buffers 38,358 (identical at every met
period, so NOT caused by failing timing: probably fanout/slew fixing around the buffer read muxes); clock tree 4,947;
tap 5,808 (included in the 179,674). Fill cells (144,326) are NOT part of logic area. `design__instance__area` includes
fill, so the collector uses `design__instance__area__stdcell`. Power is exactly proportional to frequency (energy/clock constant).
Energy/sample at 96 kHz: ~19.5 nJ with clock stopped between samples (64 x 304.5 pJ); ~127 nJ with a free-running 25 MHz clock.
Rough comparison with earlier FPGA rows: FPGA ~60 pJ/clk (DSP) to ~120 pJ/clk (no DSP) vs ASIC 304.5 pJ/clk.
ASIC runs take ~35-45 min each (run inside the WSL nix-shell from a clone in the WSL home, not from the D: flash drive).

## Expectations / hypotheses to test
- FPGA wins absolute speed and probably energy (28 nm vs 130 nm). Report each platform as ratios to its own serial MAC.
- FPGA gets multipliers from hard DSPs (90 on this part), ASIC builds them from gates: expect parallelism cheap on
  FPGA, expensive on ASIC; best architecture may differ per platform (the main question).
- ASIC energy per sample may fall for parallel cores (fewer clocks of the 1,872-flop buffer per sample).

## Remaining work (priority order)
1. Semi-parallel (4 lanes) and fully parallel folded cores, ideally one module with a LANES parameter, same ports,
   passing the 21-test bench. Key decision: sample-buffer access (shift register vs replicated/banked RAM). Ryan writes
   the core; Claude outlines and reviews.
2. Run both flows at 40, 30, 25, 20 ns for each architecture (cap ASIC at 2 periods per design variant if short on time).
3. Real switching activity (one shared SAIF/VCD from simulation, samples ~1042 clocks apart at 100 MHz / 96 kHz) for both platforms.
4. Report area/power with and without the sample buffer. Optional sweeps: coefficient/sample bit-width, buffer style.
5. MATLAB stages still placeholders: `buildPpaTable`, `parseVivado*`, `parseAsicMetrics`, `plotPpa`, `run_ppa_report` (CSVs can be read directly).
6. Hardware: channels 2 and 3, audio demo + `run_analysis` (firmware flags RELAY_RAMP_CHECK 0, RELAY_LOOPBACK_CHECK 0).
7. Poster (plan lives in the "FIR PPA Poster Plan" doc artifact): 3 columns, ~550 words, results figures 1-9.

## Housekeeping
- `matlab/data/*` is gitignored; result CSVs must be added with `git add -f`.
- Do not commit `post_route.dcp`, `asic/serial_mac/runs/`, editor `History/`/`__Previews/` folders.
- Sweep scripts never commit; the `commit` column records HEAD at run time, so commit RTL before sweeping.
- Open questions: poster deadline; whether the semi-parallel core is written by Ryan or drafted by Claude (default: Ryan writes).
