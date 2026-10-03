% run_coefficients.m
% Stage 02: turn the tap-study designs into the final fixed-point coefficient
% set: pad to a common length, one shared shift, quantize, half-sets, accumulator
% width, and the headroom limit (largest input peak that cannot overflow).
%
% Reads:  data/results/01_tap_study/fir_tap_results.mat
% Writes: data/coefficients/fir_coefficients.mat
%           coeffs  cell array of padded floating-point coefficient columns, one per channel
%           fp      fixed-point parameter struct (see lib/fixedpoint/fixedPointParams.m)
%           fc, fs  frequency plan values the coefficients were designed for

cfg = config();
fx  = cfg.fixedPoint;

tapFile = fullfile(cfg.resultsDir, '01_tap_study', 'fir_tap_results.mat');
assert(isfile(tapFile), 'Run stage 01 (run_tap_study) first: %s not found', tapFile);
S = load(tapFile);

ia = find(S.As_list == fx.asTarget, 1);
assert(~isempty(ia), 'No %d dB row in %s', fx.asTarget, tapFile);
nCh = size(S.res, 2);

hList = cell(1, nCh);
for ic = 1:nCh
    assert(~isnan(S.res(ia, ic).taps), 'Channel %d has no design at %d dB', ic, fx.asTarget);
    hList{ic} = S.res(ia, ic).h(:);
end

fp = fixedPointParams(hList, fx.coefBits);

fprintf('\n=== Fixed-point parameters ===\n');
fprintf('N_TAPS = %d, N_HALF = %d, COEF_W = %d, SHIFT = %d, ACC_W = %d\n', ...
        fp.N_TAPS, fp.N_HALF, fp.COEF_W, fp.SHIFT, fp.ACC_W);
fprintf('Worst-case gain per channel: %s  (max %.3f)\n', mat2str(fp.gain, 4), fp.maxGain);
fprintf('Headroom: input peak must be <= %d (%.1f%% of full scale) to guarantee no overflow\n', ...
        fp.INPUT_PEAK, 100 * fp.INPUT_PEAK / 32767);

fprintf('\n=== Quantized %d-bit response (worst stopband / passband ripple) ===\n', fp.COEF_W);
for ic = 1:nCh
    [As_q, Rp_q] = measureResponse(fp.hq(:, ic) / 2^fp.SHIFT, S.ch(ic), cfg.fs);
    fprintf('%-16s stopband %5.1f dB, ripple %.3f dB\n', S.ch(ic).name, As_q, Rp_q);
end

coeffs = cell(1, nCh);
for ic = 1:nCh
    coeffs{ic} = fp.h(:, ic);
end
fc = cfg.fc;
fs = cfg.fs;

if ~exist(cfg.coefDir, 'dir'), mkdir(cfg.coefDir); end
save(fullfile(cfg.coefDir, 'fir_coefficients.mat'), 'coeffs', 'fp', 'fc', 'fs');
fprintf('\nSaved %s\n', fullfile(cfg.coefDir, 'fir_coefficients.mat'));
