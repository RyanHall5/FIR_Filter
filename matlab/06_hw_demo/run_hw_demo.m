% run_hw_demo.m
% Stage 06: stream the composite signal to the STM32 (and through the FPGA) and
% capture the returned stream.
% Needs the STM32 connected and flashed (real-FPGA stage) and the Basys 3 programmed.
% Set the Basys 3 switches to the channel in cfg.hw.channel (sw[1:0] = 01, 10, 11 for ch 1, 2, 3);
% stage 07 compares the capture against that channel.
% RESET THE NUCLEO (and the FPGA, btnC) BEFORE EVERY RUN.
% Run run_hw_vector_test first to confirm the hardware is bit-exact on the test vectors.
%
% AI note: header comments updated by Claude (Anthropic) at the author's request.
%
% Reads:  data/audio/composite/<cfg.streamFile>   (int16, headroom-scaled; from stage 03)
% Writes: data/captures/<cfg.captureFile>         (sent, rx, fs; read by stage 07)

cfg = config();
fprintf('Streaming through the FPGA with the switches set to channel %d (sw[1:0] = %s).\n', ...
    cfg.hw.channel, dec2bin(cfg.hw.channel, 2));
[sent, rx] = streamToSTM32(fullfile(cfg.compDir, cfg.streamFile), cfg.fs, ...
    cfg.comPort, cfg.baudRate, cfg.chunkSamples, cfg.streamSeconds, cfg.drainSeconds);

if ~exist(cfg.captureDir, 'dir'), mkdir(cfg.captureDir); end
fs = cfg.fs;
save(fullfile(cfg.captureDir, cfg.captureFile), 'sent', 'rx', 'fs');
fprintf('Capture saved to %s\n', fullfile(cfg.captureDir, cfg.captureFile));
