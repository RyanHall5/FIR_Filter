% run_stm32_selftest.m
% Stage 05: STM32 link bring-up test (ramp send / loopback). Needs the STM32
% connected. Settings (mode, number of chunks, plotting) are in cfg.selftest.
%
% RESET THE NUCLEO (black button) BEFORE EVERY RUN. See lib/stm32/rampLoopbackTest.m.
%
% TODO (placeholders, not called yet): FPGA echo and latency measurement via
% alignLatency once stage 07 exists.

cfg = config();
rampLoopbackTest(cfg);
