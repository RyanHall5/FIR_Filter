function cfg = config()
% config  Single source of truth for every constant/parameter used across
%         the entire project (stage scripts, lib functions, tests).
%
%   cfg = config()
%
%   Change values HERE. Every other file is driven by this struct and
%   should not hardcode constants of its own.

    % --- Project root (this file lives in <root>/config/) ---
    root = fileparts(fileparts(mfilename('fullpath')));
    cfg.root = root;

    % --- Songs ---
    cfg.songs = {'DieWithSmile', 'Jealous', 'Umbrella'};

    % --- Folders (absolute paths, anchored at the project root) ---
    cfg.dataDir    = fullfile(root, 'data');
    cfg.sourceDir  = fullfile(cfg.dataDir, 'audio', 'source');
    cfg.normDir    = fullfile(cfg.dataDir, 'audio', 'normalized');
    cfg.compDir    = fullfile(cfg.dataDir, 'audio', 'composite');
    cfg.coefDir    = fullfile(cfg.dataDir, 'coefficients');
    cfg.vectorDir  = fullfile(cfg.dataDir, 'vectors');
    cfg.captureDir = fullfile(cfg.dataDir, 'captures');
    cfg.resultsDir = fullfile(cfg.dataDir, 'results');   % one subfolder per stage
    cfg.ppaDir     = fullfile(cfg.dataDir, 'ppa_reports');

    % --- Sample rate ---
    cfg.fs = 96000;

    % --- Frequency plan ---
    cfg.fc         = [8000, 22000, 36000];   % carrier center freq per channel (Hz)
    cfg.basebandBW = 6000;                    % baseband bandwidth per channel (Hz)
    cfg.guardBW    = 2000;                    % guard band on each side (Hz)

    % --- Stage 01: tap-count study ---
    % ASSUMPTION (see lib/dsp/channelBands.m): the regions outside the outermost
    % channels (below the first, above the last) are empty, so the first channel
    % is designed as a lowpass and the last as a highpass.
    cfg.tapStudy.asList     = [40 60 80];          % stopband targets to compare (dB)
    cfg.tapStudy.rippleDb   = 0.5;                 % passband ripple, peak-to-peak (dB)
    cfg.tapStudy.coefBits   = 16;                  % coefficient width for the main table
    cfg.tapStudy.bitsSweep  = [10 12 14 16 18];    % widths for the coefficient-width sweep
    cfg.tapStudy.asSweep    = 60;                  % target used in the width sweep
    cfg.tapStudy.asPlot     = 60;                  % target used in the response plot
    cfg.tapStudy.searchBack = 20;                  % start search this many taps below firpmord estimate
    cfg.tapStudy.searchFwd  = 200;                 % give up this many taps above the estimate

    % --- Stage 02: final fixed-point design ---
    cfg.fixedPoint.asTarget = 60;     % which stopband-target row of the tap study to use (dB)
    cfg.fixedPoint.coefBits = 16;     % coefficient width (try 16 to reach the full 60 dB)

    % --- Stage 04: golden model test signals ---
    cfg.golden.sigLength   = 8192;    % samples in the long test signals
    cfg.golden.noiseLevel  = 0.1;     % white-noise level added to the tone composite
    cfg.golden.rngSeed     = 1;       % fixed seed so vectors are reproducible

    % --- Quantization of streamed audio ---
    cfg.sampleBits = 16;   % fixed-point word width for streamed audio samples
    cfg.streamFile = 'composite_int16.bin';   % headroom-scaled int16 stream, in cfg.compDir

    % --- STM32 streaming ---
    cfg.comPort       = 'COM4';       % <-- CHANGE to your STM32's actual serial port
    cfg.baudRate      = 2250000;      % baud
    cfg.chunkSamples  = 512;          % matches STM32's double-buffered ring buffer size
    cfg.streamSeconds = 20;            % seconds to stream for this test (use Inf for full song)
    cfg.drainSeconds  = 2;            % keep reading this long after the last chunk is sent
    cfg.captureFile   = 'hw_capture.mat';   % stage 06 output (in cfg.captureDir), stage 07 input
    cfg.maxLag        = 4096;         % largest latency alignLatency searches (samples)

    % --- Stage 06/07: hardware demo (Basys 3 running top.v) ---
    cfg.hw.channel      = 3;        % channel the Basys 3 switches are set to: sw[1:0] = 01, 10, 11 for ch 1, 2, 3
    cfg.hw.expectedLag  = 2;        % samples the returned stream trails the sent stream (top.v tx_hold design)
    cfg.hw.flushSamples = 512;      % zeros sent ahead of each vector test to flush the filter history (multiple of chunkSamples)
    cfg.hw.vectorTests  = {'impulse', 'step', 'composite'};   % in_<name>.hex vectors sent by the vector test
    cfg.hw.playAudio    = true;     % stage 07 plays the demodulated channel

    % --- Stage 05: STM32 self-test ---
    cfg.selftest.mode      = 'loopback';   % 'send' or 'loopback'
    cfg.selftest.numChunks = 200;          % chunks of cfg.chunkSamples samples
    cfg.selftest.showPlot  = true;

    % --- Stage 09: PPA report and poster figures (added with Claude, Anthropic) ---
    % Inputs are the summary CSVs written by fpga/scripts/run_fpga_ppa.tcl and
    % asic/scripts/run_asic_ppa.py. The ASIC sweep runs in WSL, so copy its
    % asic_ppa_summary.csv into data/ppa_reports/asic/ before running stage 09.
    cfg.ppa.fpgaCsv = fullfile(cfg.ppaDir, 'fpga', 'fpga_ppa_summary.csv');
    cfg.ppa.asicCsv = fullfile(cfg.ppaDir, 'asic', 'asic_ppa_summary.csv');
    cfg.ppa.lanes           = [1 2 4 8 16];     % LANES values in the sweep
    cfg.ppa.clocksPerSample = [64 35 20 13 9];  % measured in FIR_Core_Mac_tb (sample_valid -> out_valid)
    cfg.ppa.fpgaVariant     = 'dsp';            % FPGA build shown on the poster ('dsp' or 'nodsp')
    cfg.ppa.refPeriodNs     = 40;               % 25 MHz operating point: area and power are taken here
    cfg.ppa.asicFailedLanes = 8;                % ASIC lane counts that did not route (marked on figures)
    cfg.ppa.requiredMsps    = cfg.fs / 1e6;     % sample-rate requirement (0.096 MS/s)
    cfg.ppa.colors.fpga  = [15 139 141] / 255;  % teal   #0F8B8D
    cfg.ppa.colors.asic  = [200 105 44] / 255;  % copper #C8692C
    cfg.ppa.colors.navy  = [14 27 44] / 255;    % navy   #0E1B2C
    cfg.ppa.colors.text  = [31 35 40] / 255;    % charcoal #1F2328
    cfg.ppa.colors.muted = [90 98 112] / 255;   % slate  #5A6270
    cfg.ppa.colors.grid  = [208 213 219] / 255; % light grey #D0D5DB
    cfg.ppa.font     = 'IBM Plex Sans';         % falls back to Helvetica if not installed
    cfg.ppa.fontSize = 24;                      % pt at final print size (poster minimum)
    % Figure sizes in inches at print size [width height], to match the poster layout
    cfg.ppa.figSize.area      = [12.5 3.9];     % Fig. 6, centre column
    cfg.ppa.figSize.speed     = [12.5 3.9];     % Fig. 7, centre column
    cfg.ppa.figSize.energy    = [8.5 3.0];      % Fig. 8, right column
    cfg.ppa.figSize.power     = [8.5 2.7];      % Fig. 9, right column
    cfg.ppa.figSize.areaSplit = [8.5 2.7];      % Fig. 10, right column

    % --- Which stages run_all executes ---
    cfg.run.tapStudy      = false;
    cfg.run.coefficients  = false;
    cfg.run.audioPrep     = false;
    cfg.run.goldenModel   = false;
    cfg.run.stm32Selftest = false;   % needs the STM32 connected
    cfg.run.hwDemo        = true;   % needs the STM32 (and FPGA) connected; replaces the old cfg.doStream
    cfg.run.hwVectorTest  = false;   % needs the STM32 and FPGA connected; bit-exact test with the golden vectors
    cfg.run.analysis      = true;   % placeholder stage
    cfg.run.visualize     = false;
    cfg.run.ppaReport     = false;   % poster figures from the PPA summary CSVs
end
