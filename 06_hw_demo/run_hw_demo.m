% run_hw_demo.m
% Stage 06: stream the composite signal to the STM32 (and through the FPGA).
% Needs the STM32 connected and its firmware flashed and listening.
%
% Reads:  data/audio/composite/<cfg.streamFile>   (int16, headroom-scaled; from stage 03)
%
% TODO (placeholders, not called yet), in this order once the firmware protocol exists:
%   s = openLink(cfg);  sendCoefficients(s, fp);  setChannel(s, channel);
%   concurrent send/receive with capture to data/captures/;  closeLink(s);
% streamToSTM32 currently sends only and does not read back the returned stream.

cfg = config();
streamToSTM32(fullfile(cfg.compDir, cfg.streamFile), cfg.fs, ...
    cfg.comPort, cfg.baudRate, cfg.chunkSamples, cfg.streamSeconds);