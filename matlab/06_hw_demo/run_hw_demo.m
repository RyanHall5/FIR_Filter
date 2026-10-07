% run_hw_demo.m
% Stage 06: stream the composite signal to the STM32 (and through the FPGA) and
% capture the returned stream.
% Needs the STM32 connected and its firmware flashed and listening.
% RESET THE NUCLEO (and the FPGA) BEFORE EVERY RUN.
%
% Reads:  data/audio/composite/<cfg.streamFile>   (int16, headroom-scaled; from stage 03)
% Writes: data/captures/<cfg.captureFile>         (sent, rx, fs; read by stage 07)
%
% TODO (placeholders, not called yet), once the firmware protocol exists:
%   s = openLink(cfg);  sendCoefficients(s, fp);  setChannel(s, channel);  closeLink(s);

cfg = config();
[sent, rx] = streamToSTM32(fullfile(cfg.compDir, cfg.streamFile), cfg.fs, ...
    cfg.comPort, cfg.baudRate, cfg.chunkSamples, cfg.streamSeconds, cfg.drainSeconds);

if ~exist(cfg.captureDir, 'dir'), mkdir(cfg.captureDir); end
fs = cfg.fs;
save(fullfile(cfg.captureDir, cfg.captureFile), 'sent', 'rx', 'fs');
fprintf('Capture saved to %s\n', fullfile(cfg.captureDir, cfg.captureFile));
