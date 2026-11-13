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
    % Data settings only; how the charts look is set in cfg.poster below.
    % Inputs are the summary CSVs written by fpga/scripts/run_fpga_ppa.tcl and
    % asic/scripts/run_asic_ppa.py. The ASIC sweep runs in WSL, so copy its
    % asic_ppa_summary.csv into data/ppa_reports/asic/ before running stage 09.
    cfg.ppa.fpgaCsv = fullfile(cfg.ppaDir, 'fpga', 'fpga_ppa_summary.csv');
    cfg.ppa.asicCsv = fullfile(cfg.ppaDir, 'asic', 'asic_ppa_summary.csv');
    cfg.ppa.lanes           = [1 2 4 8 16];     % LANES values in the sweep
    cfg.ppa.clocksPerSample = [64 35 20 13 9];  % measured in FIR_Core_Mac_tb (sample_valid -> out_valid)
    cfg.ppa.fpgaVariant     = 'dsp';            % FPGA build shown on the poster ('dsp' or 'nodsp')
    cfg.ppa.refPeriodNs     = 40;               % 25 MHz operating point: area and power are taken here
    cfg.ppa.asicFailedLanes = 8;                % ASIC lane counts that did not route (marked "did not route" on the charts)
    cfg.ppa.requiredMsps    = cfg.fs / 1e6;     % sample-rate requirement (0.096 MS/s)

    % --- Poster charts: one look for every chart (added with Claude, Anthropic) ---
    % Used by lib/plot/posterKit.m, plotPpa.m and plotFilterPoster.m. The poster canvas is
    % 3456 x 2304 px for 36 x 24 in, so 96 px = 1 in and a chart drawn at its slot size in
    % inches prints with real point sizes. Charts carry no title or caption (the poster
    % card supplies both); they are exported as PNG at exactly figSize x exportDpi.
    cfg.poster.pxPerIn       = 96;                 % poster canvas pixels per printed inch
    cfg.poster.exportDpi     = 600;                % PNG resolution (a 7.15 in chart is 4290 px wide)
    cfg.poster.font          = 'IBM Plex Sans';    % poster typeface; falls back to Helvetica with a warning
    cfg.poster.fontSize      = 17;                 % pt: axis numbers, axis titles, header, colour key
    cfg.poster.valueFontSize = 16;                 % pt: values printed at points and bar tops
    cfg.poster.noteFontSize  = 15;                 % pt: small notes ("did not route") and the in-plot key
    cfg.poster.colors.fpga      = [15 139 141] / 255;    % teal   #0F8B8D
    cfg.poster.colors.fpgaLight = [147 203 204] / 255;   % light teal #93CBCC (FPGA static power)
    cfg.poster.colors.asic      = [200 105 44] / 255;    % copper #C8692C
    cfg.poster.colors.asicLight = [228 180 149] / 255;   % light copper #E4B495 (ASIC buffer cells)
    cfg.poster.colors.navy      = [14 27 44] / 255;      % navy   #0E1B2C
    cfg.poster.colors.text      = [31 35 40] / 255;      % charcoal #1F2328
    cfg.poster.colors.muted     = [90 98 112] / 255;     % slate  #5A6270
    cfg.poster.colors.grid      = [208 213 219] / 255;   % light grey #D0D5DB
    cfg.poster.colors.channels  = {[14 27 44] / 255, [62 106 154] / 255, [143 179 217] / 255};   % ch 1-3: navy, steel, light blue
    cfg.poster.lineWidth     = 2.5;                % pt: data lines
    cfg.poster.markerSize    = 9;                  % pt: data markers
    cfg.poster.barWidth      = 0.58;               % single bars, as a fraction of one lane slot
    cfg.poster.pairBarWidth  = 0.36;               % each bar of an FPGA/ASIC pair
    cfg.poster.pairOffset    = 0.20;               % pair bars sit this far either side of the lane position
    % Figure sizes [width height] in inches = slot on the poster / 96
    cfg.poster.figSize.result = [7.15 2.75];       % Figs. 6-9: 686 x 264 px chart area of a centre-grid card
    cfg.poster.figSize.filter = [7.85 3.00];       % Fig. 1: 756 px wide left-column card (image height follows)
    % Margins around the plot area, inches
    cfg.poster.headIn        = 0.40;               % header row above the plot (what is plotted + colour key)
    cfg.poster.botIn         = 0.74;               % below the plot: axis numbers and axis title
    cfg.poster.leftIn        = 0.55;               % left of the plot: room for three-character axis numbers
    cfg.poster.rightIn       = 0.06;
    cfg.poster.headerXIn     = 0.04;               % header text starts here (left edge of the image)
    cfg.poster.xTitleDropIn  = 0.62;               % axis title baseline below the axis line
    cfg.poster.barLabelGapIn  = 0.05;              % gap between a bar top and its value
    cfg.poster.lineLabelGapIn = 0.10;              % gap between a marker centre and its value
    cfg.poster.labelRoomIn   = 0.34;               % headroom kept above the tallest mark for its value
    cfg.poster.swatchIn      = 0.17;               % colour-key sample size
    cfg.poster.keyTextGapIn  = 0.12;               % sample to its label
    cfg.poster.keyItemGapIn  = 0.28;               % between key entries in a row
    cfg.poster.keyRowPitchIn = 0.27;               % between key rows in a column

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
