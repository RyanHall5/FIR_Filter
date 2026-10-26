% run_analysis.m
% Stage 07: analyse what the hardware returned from the audio demo (stage 06).
%   1. Run the golden FIR on exactly what was sent, for the selected channel.
%   2. Find the latency with alignLatency and compare bit-exactly against the golden output.
%   3. Demodulate the returned channel to baseband, plot the spectra, save and play the audio.
%
% AI note: updated by Claude (Anthropic) at the author's request (golden-FIR comparison,
% demodulation, plots and playback). The original stage script compared against the sent
% stream, which is right only for the old echo design.
%
% The channel is cfg.hw.channel: it must match the Basys 3 switches during the run.
% Run the hardware vector test (run_hw_vector_test) first; this stage assumes the hardware
% already matches the golden model on the test vectors.
%
% Reads:  data/captures/<cfg.captureFile>, data/coefficients/fir_coefficients.mat
% Writes: data/results/07_analysis/ch<N>_demod.wav

cfg = config();
ch  = cfg.hw.channel;

c = load(fullfile(cfg.captureDir, cfg.captureFile));   % sent, rx, fs
S = load(fullfile(cfg.coefDir, 'fir_coefficients.mat'));
fp = S.fp;

% ---- 1. golden output for what was actually sent (padded last chunk included) ----
yGold = goldenFir(double(c.sent(:)), fp.h_half(:, ch), fp.SHIFT, fp.COEF_W);

% ---- 2. align and compare bit-exactly ----
[rxAligned, lag] = alignLatency(c.rx, yGold, cfg.maxLag);
n = min(numel(rxAligned), numel(yGold));
bad = find(double(rxAligned(1:n)) ~= yGold(1:n));

fprintf('Channel %d: sent %d samples, received %d.\n', ch, numel(c.sent), numel(c.rx));
fprintf('Latency: %d samples (%.1f us); expected %d\n', lag, 1e6 * lag / c.fs, cfg.hw.expectedLag);
if lag ~= cfg.hw.expectedLag
    warning('run_analysis:lag', 'Latency %d differs from cfg.hw.expectedLag %d.', lag, cfg.hw.expectedLag);
end
fprintf('Compared %d aligned samples against the golden FIR: %d mismatches', n, numel(bad));
if isempty(bad)
    fprintf('  -> PASS (bit-exact)\n');
else
    k = bad(1);
    fprintf('\n  First mismatch at sample %d: golden %d, got %d\n', k, yGold(k), rxAligned(k));
    fprintf('  Check that cfg.hw.channel matches the switches, and that the run started right after a reset.\n');
end
fprintf('Samples sent but not returned: %d (expected the latency, %d)\n', numel(c.sent) - n, lag);

% ---- 3. demodulate, plot, save, play ----
resDir = fullfile(cfg.resultsDir, '07_analysis');
if ~exist(resDir, 'dir'), mkdir(resDir); end

yf         = double(rxAligned(1:n)) / 2^(cfg.sampleBits - 1);
groupDelay = (fp.N_TAPS - 1) / 2;                         % channel filter delay (58 samples)
xd         = demodChannel(yf, c.fs, cfg.fc(ch), cfg.basebandBW, groupDelay);

fsOut = c.fs / 2;                                          % baseband is 6 kHz wide: 48 kHz is plenty
xd    = resample(xd, 1, 2);
xd    = 0.9 * xd / max(abs(xd));
wavFile = fullfile(resDir, sprintf('ch%d_demod.wav', ch));
audiowrite(wavFile, xd, fsOut);
fprintf('Demodulated channel %d written to %s\n', ch, wavFile);

figure('Name', 'Hardware result spectra');
subplot(3, 1, 1);
plotSpectrum(double(c.sent(:)) / 2^(cfg.sampleBits - 1), c.fs, 'Sent composite (all channels)');
subplot(3, 1, 2);
plotSpectrum(yf, c.fs, sprintf('Returned from the FPGA: channel %d isolated', ch));
subplot(3, 1, 3);
plotSpectrum(xd, fsOut, sprintf('Channel %d demodulated to baseband', ch));

if cfg.hw.playAudio
    fprintf('Playing channel %d ...\n', ch);
    soundsc(xd, fsOut);
end
