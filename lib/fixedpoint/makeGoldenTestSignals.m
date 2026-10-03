function tests = makeGoldenTestSignals(cfg, fp)
% makeGoldenTestSignals  Build the int16 test signals for the golden model.
%
%   tests = makeGoldenTestSignals(cfg, fp)
%
%   cfg - config() (uses fs, fc, golden.*)
%   fp  - fixedPointParams result (uses hq, N_TAPS, INPUT_PEAK)
%
%   All signals stay within fp.INPUT_PEAK, so no channel can overflow.
%   tests is a struct array with fields .name and .x (column vector):
%     composite  tones at every carrier frequency plus white noise
%     impulse    one full-peak sample (reveals coefficient order)
%     step       DC at full peak
%     noise      random values within +-INPUT_PEAK
%     stress_chN worst case for channel N (input signs match the coefficient signs)

    g      = cfg.golden;
    L      = g.sigLength;
    fs     = cfg.fs;
    inPeak = fp.INPUT_PEAK;
    nCh    = size(fp.hq, 2);

    rng(g.rngSeed);
    t   = (0:L-1)' / fs;
    sig = zeros(L, 1);
    for k = 1:numel(cfg.fc)
        sig = sig + sin(2*pi*cfg.fc(k)*t);
    end
    sig = sig + g.noiseLevel * randn(L, 1);

    tests = struct('name', {}, 'x', {});
    tests(end+1) = struct('name', 'composite', 'x', round(sig / max(abs(sig)) * inPeak));
    tests(end+1) = struct('name', 'impulse',   'x', [inPeak; zeros(fp.N_TAPS + 20, 1)]);
    tests(end+1) = struct('name', 'step',      'x', inPeak * ones(fp.N_TAPS + 60, 1));
    tests(end+1) = struct('name', 'noise',     'x', randi([-inPeak, inPeak], L, 1));
    for ic = 1:nCh
        xs = inPeak * sign(flipud(fp.hq(:, ic)));
        tests(end+1) = struct('name', sprintf('stress_ch%d', ic), 'x', [xs; zeros(20, 1)]);
    end
end
