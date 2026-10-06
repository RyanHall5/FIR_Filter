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
    cfg.songs = {'song1', 'song2', 'song3'};

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
    cfg.fixedPoint.coefBits = 14;     % coefficient width (try 16 to reach the full 60 dB)

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
    cfg.streamSeconds = 5;            % seconds to stream for this test (use Inf for full song)

    % --- Stage 05: STM32 self-test ---
    cfg.selftest.mode      = 'loopback';   % 'send' or 'loopback'
    cfg.selftest.numChunks = 200;          % chunks of cfg.chunkSamples samples
    cfg.selftest.showPlot  = true;

    % --- Which stages run_all executes ---
    cfg.run.tapStudy      = true;
    cfg.run.coefficients  = true;
    cfg.run.audioPrep     = true;
    cfg.run.goldenModel   = true;
    cfg.run.stm32Selftest = true;   % needs the STM32 connected
    cfg.run.hwDemo        = true;   % needs the STM32 (and FPGA) connected; replaces the old cfg.doStream
    cfg.run.analysis      = false;   % placeholder stage
    cfg.run.visualize     = false;
    cfg.run.ppaReport     = false;   % placeholder stage
end
