% run_analysis.m
% Stage 07: analyse what the hardware returned.
%
% STATUS: PARTIAL. Implemented: load the stage 06 capture, find the latency with
% alignLatency, and compare bit-exactly against what was sent (valid for the echo
% FPGA design, whose output is the input delayed). Not implemented yet:
%   - comparison against the golden FIR output in data/vectors/ (once the FIR is in the FPGA)
%   - demodChannel / channelIsolation / plots / data/results/07_analysis outputs
%
% Reads: data/captures/<cfg.captureFile>.

cfg = config();
c = load(fullfile(cfg.captureDir, cfg.captureFile));   % sent, rx, fs

[rxAligned, lag] = alignLatency(c.rx, c.sent, cfg.maxLag);
n = min(numel(rxAligned), numel(c.sent));
bad = find(rxAligned(1:n) ~= c.sent(1:n));

fprintf('Sent %d samples, received %d.\n', numel(c.sent), numel(c.rx));
fprintf('Latency: %d samples (%.1f us)\n', lag, 1e6 * lag / c.fs);
fprintf('Compared %d aligned samples: %d mismatches', n, numel(bad));
if isempty(bad)
    fprintf('  -> PASS (bit-exact)\n');
else
    k = bad(1);
    fprintf('\n  First mismatch at sample %d: sent %d, got %d\n', k, c.sent(k), rxAligned(k));
end
% Samples lost off the end: the last `lag` samples sent come back after the capture ends,
% so numel(c.sent) - n is normally equal to lag.
fprintf('Samples sent but not returned: %d (expected about the latency, %d)\n', numel(c.sent) - n, lag);
