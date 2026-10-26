% run_hw_vector_test.m
% Stage 06 (vector test): send the golden test vectors through STM32 -> FPGA -> STM32 and
% compare the returned stream bit-exactly with the expected outputs from stage 04.
% Run this BEFORE the audio demo: the impulse test shows the filter coefficients
% directly, so a coefficient, channel or alignment problem is obvious.
%
% Needs the STM32 connected and flashed (real-FPGA stage), the Basys 3 programmed, and the
% Basys 3 switches set to the channel in cfg.hw.channel (sw[1:0] = 01, 10, 11 for ch 1, 2, 3).
% RESET THE NUCLEO AND THE FPGA (btnC) BEFORE EVERY RUN.
%
% AI note: written by Claude (Anthropic) at the author's request.
%
% Reads:  data/vectors/in_<test>.hex, exp_<test>_ch<N>.hex   (stage 04)
% Writes: data/captures/vec_<test>.bin (the stream sent) and hw_vector_<test>_ch<N>.mat
%
% How the comparison lines up: each test is sent behind cfg.hw.flushSamples zeros (so the
% filter history left by the previous test is flushed, and the golden model's all-zero
% starting history holds), and one chunk of zeros follows it, because the last
% cfg.hw.expectedLag outputs only come back while later words are being sent. The word
% returned in slot m is the filter output for the sample sent in slot m - cfg.hw.expectedLag. So the output for the k-th test sample
% is rx(flushSamples + expectedLag + k).

cfg = config();
ch  = cfg.hw.channel;
lag = cfg.hw.expectedLag;
P   = cfg.hw.flushSamples;
assert(mod(P, cfg.chunkSamples) == 0, ...
    'cfg.hw.flushSamples (%d) must be a multiple of cfg.chunkSamples (%d)', P, cfg.chunkSamples);
if ~exist(cfg.captureDir, 'dir'), mkdir(cfg.captureDir); end

names = cfg.hw.vectorTests;
fprintf('\n=== Hardware vector test: channel %d (sw[1:0] = %s), expected lag %d ===\n', ...
    ch, dec2bin(ch, 2), lag);
fprintf('Make sure the Basys 3 switches are set to this channel.\n');

nFail = 0;
for it = 1:numel(names)
    name = names{it};
    x    = readHex(fullfile(cfg.vectorDir, sprintf('in_%s.hex', name)), 16);
    yExp = readHex(fullfile(cfg.vectorDir, sprintf('exp_%s_ch%d.hex', name, ch)), 16);

    % Write the stream file: flush zeros, then the test vector (raw little-endian int16)
    streamFile = fullfile(cfg.captureDir, sprintf('vec_%s.bin', name));
    fid = fopen(streamFile, 'w', 'ieee-le');
    assert(fid > 0, 'Cannot open %s for writing.', streamFile);
    fwrite(fid, int16([zeros(P, 1); x; zeros(cfg.chunkSamples, 1)]), 'int16');   % trailing zeros let the last outputs come back
    fclose(fid);

    fprintf('\n--- %s (%d samples) ---\n', name, numel(x));
    [sent, rx] = streamToSTM32(streamFile, cfg.fs, cfg.comPort, cfg.baudRate, ...
        cfg.chunkSamples, Inf, cfg.drainSeconds);

    % Compare the output for each test sample
    first = P + lag;
    n = min(numel(x), numel(rx) - first);
    if n < numel(x)
        fprintf('  WARNING: only %d of %d outputs were received.\n', max(n, 0), numel(x));
    end
    got = double(rx(first + (1:n)));
    bad = find(got ~= yExp(1:n));

    if n == numel(x) && isempty(bad)
        fprintf('  %s: PASS (%d samples bit-exact)\n', name, n);
    else
        nFail = nFail + 1;
        fprintf('  %s: FAIL (%d mismatches in %d samples)\n', name, numel(bad), n);
        if ~isempty(bad)
            k = bad(1);
            fprintf('    first mismatch at test sample %d: expected %d, got %d\n', k, yExp(k), got(k));
        end

        % Diagnostic: does the returned stream match at some other lag?
        bestL = lag; bestM = -1;
        for L = 0:8
            nL = min(numel(x), numel(rx) - (P + L));
            if nL < 1, continue; end
            m = sum(double(rx(P + L + (1:nL))) == yExp(1:nL));
            if m > bestM, bestM = m; bestL = L; end
        end
        fprintf('    best match over lags 0..8: lag %d (%d of %d samples)\n', bestL, bestM, numel(x));
        if bestL ~= lag
            fprintf('    The data matches at a different lag: check cfg.hw.expectedLag and the FPGA top.v.\n');
        end
    end

    save(fullfile(cfg.captureDir, sprintf('hw_vector_%s_ch%d.mat', name, ch)), ...
        'sent', 'rx', 'x', 'yExp', 'got', 'lag', 'P');
end

if nFail == 0
    fprintf('\nALL HARDWARE VECTOR TESTS PASSED\n');
else
    fprintf('\n%d HARDWARE VECTOR TEST(S) FAILED\n', nFail);
end
