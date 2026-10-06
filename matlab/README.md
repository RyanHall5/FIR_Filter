# MATLAB (matlab/)

Channel-select FIR filter project: build a three-song composite, design and
quantize the channel filters, produce bit-exact reference vectors for the Verilog
testbenches, stream through the STM32 and FPGA, and analyse the result.

## Layout

Every stage folder holds exactly ONE runnable script. All functions live in
`lib/`. All generated and input files live in `data/`.

```
config/config.m           single source of truth for every constant (a function, not run directly)
00_master/run_all.m       runs the stages below in order, switched by cfg.run flags
01_tap_study/             run_tap_study.m      taps vs stopband vs coefficient width
02_coefficients/          run_coefficients.m   final fixed-point coefficient set, shared shift, headroom limit
03_audio_prep/            run_audio_prep.m     normalize songs, build the composite
04_golden_model/          run_golden_model.m   golden-model checks, hex vectors for the testbenches
05_stm32_selftest/        run_stm32_selftest.m ramp send / loopback link test         (needs STM32)
06_hw_demo/               run_hw_demo.m        stream the composite to the STM32/FPGA (needs STM32)
07_analysis/              run_analysis.m       PLACEHOLDER
08_visualize/             run_visualize.m      spectra, filter responses, composite plots
09_ppa_report/            run_ppa_report.m     PLACEHOLDER
tests/run_tests.m         runs tests/cases/*   (all PLACEHOLDER tests so far)
lib/{audio,dsp,fixedpoint,stm32,plot,ppa,util}/   functions only
data/                     audio, coefficients, vectors, captures, results/<stage>/, ppa_reports/{fpga,asic}
archive/legacy/           superseded code kept for reference (not on the path)
```

## One-time setup

The project is meant to be opened as a MATLAB Project (`FIR_Filter.prj`) so the
path is managed for you. The old project metadata was removed because it
listed the old file locations, so register the folders once:

```matlab
proj = openProject('FIR_Filter.prj');            % run from the matlab/ folder
addPath(proj, fullfile(proj.RootFolder, 'config'));
addPath(proj, genpath(fullfile(proj.RootFolder, 'lib')));
```

If you would rather not use the project, `addpath(fullfile(pwd,'config'), genpath(fullfile(pwd,'lib')))`
from matlab/ does the same job for the current session.

## Usage

1. Put the three source MP3s in `data/audio/source/` as `song1.mp3`, `song2.mp3`, `song3.mp3`.
2. Edit `config/config.m` (COM port, coefficient width, which stages run, ...).
3. Run `00_master/run_all.m`, or run any stage on its own: each stage reads the
   files the earlier stages wrote under `data/`.

| Stage | Reads | Writes |
|---|---|---|
| 01 tap study | config | `data/results/01_tap_study/fir_tap_results.mat` |
| 02 coefficients | 01 results | `data/coefficients/fir_coefficients.mat` |
| 03 audio prep | `data/audio/source` | `data/audio/normalized`, `data/audio/composite` |
| 04 golden model | 02 coefficients | `data/vectors/` |
| 05 selftest | config | console output |
| 06 hw demo | `data/audio/composite` | (captures, once implemented) |
| 08 visualize | audio and coefficient files | figures |

Stages 05 and 06 need the STM32 connected and default to off in `cfg.run`.
Stages 07 and 09 are placeholders.

## Rules for adding code

- Constants live in `config/config.m` only.
- Stage scripts call `config()` and `lib/` functions and handle files and printing; algorithms go in `lib/`.
- A new stage folder gets one runnable script; anything else goes in `lib/`.
- Naming is camelCase.

## Notes

- The Signal Processing Toolbox is required (`firpmord`, `firpm`, `freqz`, `resample`, `fir1`, `pspectrum`).
  `xline` (used in `plotFilterResponses`) needs MATLAB R2018b or newer.
- Placeholder functions throw `<name>:notImplemented` when called; placeholder tests report as incomplete.
- `archive/legacy/designCoefficients.m` is the original 101-tap bandpass design. Stage 01/02 replace it
  (stage 01 designs with the band edges from the frequency plan, stage 02 quantizes). Delete it when you no longer need it.
