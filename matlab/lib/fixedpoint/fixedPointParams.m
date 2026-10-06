function fp = fixedPointParams(hList, coefBits)
% fixedPointParams  Turn the floating-point channel filters into the fixed-point
%                   parameter set shared by the golden model and every RTL core.
%
%   fp = fixedPointParams(hList, coefBits)
%
%   hList     - cell array, one floating-point coefficient vector per channel
%               (odd, possibly different lengths)
%   coefBits  - coefficient width in bits
%
%   Steps: pad every channel to the longest length (equal zeros each side keeps
%   symmetry and the centre tap aligned), pick ONE shared output shift (the
%   hardware has a single fixed shift), quantize, check symmetry, take the half
%   set the core stores, and work out accumulator width and headroom.
%
%   fp fields:
%     N_TAPS, N_HALF, COEF_W, SHIFT, ACC_W, INPUT_PEAK (=inPeak)
%     h        padded floating-point coefficients, N_TAPS-by-nCh
%     hq       integer coefficients, N_TAPS-by-nCh
%     h_half   hq(1:N_HALF, :), centre tap last (what the core stores)
%     gain     worst-case gain per channel
%     maxGain  max over channels

    nCh    = numel(hList);
    lens   = cellfun(@numel, hList);
    N_TAPS = max(lens);
    assert(mod(N_TAPS, 2) == 1, 'Tap count must be odd for the folded structure');
    N_HALF = (N_TAPS + 1) / 2;

    h = zeros(N_TAPS, nCh);
    for ic = 1:nCh
        hc  = hList{ic}(:);
        pad = (N_TAPS - numel(hc)) / 2;
        h(:, ic) = [zeros(pad, 1); hc; zeros(pad, 1)];
    end

    maxInt = 2^(coefBits - 1) - 1;
    SHIFT  = floor(log2(maxInt / max(abs(h(:)))));   % largest shift that fits every channel

    hq = zeros(N_TAPS, nCh);
    for ic = 1:nCh
        hq(:, ic) = quantizeCoefs(h(:, ic), coefBits, SHIFT);
        assert(isequal(hq(:, ic), flipud(hq(:, ic))), ...
               'Channel %d coefficients are not symmetric', ic);
    end

    ACC_W = 17 + coefBits + ceil(log2(N_HALF));      % 17-bit pre-add x coefBits, summed N_HALF times
    [gain, maxGain, inPeak] = headroomLimit(hq, SHIFT);

    fp.N_TAPS     = N_TAPS;
    fp.N_HALF     = N_HALF;
    fp.COEF_W     = coefBits;
    fp.SHIFT      = SHIFT;
    fp.ACC_W      = ACC_W;
    fp.INPUT_PEAK = inPeak;
    fp.h          = h;
    fp.hq         = hq;
    fp.h_half     = hq(1:N_HALF, :);
    fp.gain       = gain;
    fp.maxGain    = maxGain;
end
