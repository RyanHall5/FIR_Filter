function [y, info] = goldenFir(x, h_half, shift, coefBits)
% GOLDENFIR  Bit-exact reference for the symmetric (folded) FIR core.
%
%   x        : input samples, integers in int16 range
%   h_half   : integer coefficients h[0..(N-1)/2], centre tap LAST (N odd)
%   shift    : output truncation shift (accumulator bits dropped)
%   coefBits : coefficient width (only used for range checks)
%
% Arithmetic (this is the contract every RTL architecture must match):
%   - sample history starts at zero (the reset state)
%   - for each mirrored tap pair, pre-add the two samples, then multiply once
%   - accumulate with no loss of precision
%   - truncate: y = floor(acc / 2^shift)  (arithmetic shift right)
%   - output sample n lines up with input sample n (no latency modelled)
%
% Doubles hold integers exactly up to 2^53, and every value here stays far
% below that, so this is exact integer arithmetic.
    x = x(:);
    h_half = h_half(:);
    L     = numel(x);
    nHalf = numel(h_half);
    N     = 2 * nHalf - 1;

    assert(all(x == round(x)) && all(x >= -32768 & x <= 32767), ...
           'goldenFir: x must be int16-range integers');
    maxC = 2^(coefBits - 1) - 1;
    assert(all(h_half == round(h_half)) && all(h_half >= -maxC - 1 & h_half <= maxC), ...
           'goldenFir: coefficients out of range for %d bits', coefBits);

    % ---- folded datapath ----
    acc = zeros(L, 1);
    for k = 0 : nHalf - 2
        pre = delayZero(x, k) + delayZero(x, N - 1 - k);   % 17-bit pre-add
        acc = acc + h_half(k + 1) * pre;
    end
    acc = acc + h_half(nHalf) * delayZero(x, nHalf - 1);    % centre tap, no pre-add

    % ---- self-check: folding must equal the plain 117-tap convolution ----
    h_full  = [h_half; flipud(h_half(1:end-1))];
    acc_ref = filter(h_full, 1, x);
    assert(isequal(acc, acc_ref), 'goldenFir: folded result differs from direct form');

    % ---- truncate ----
    y = floor(acc / 2^shift);

    % ---- report ----
    maxAbs = max(abs(acc));
    info.acc            = acc;
    info.accMaxAbs      = maxAbs;
    info.accBitsNeeded  = ceil(log2(maxAbs + 1)) + 1;        % +1 for sign
    info.overflowCount  = sum(y > 32767 | y < -32768);
end

function d = delayZero(x, k)
% x delayed by k samples, zeros shifted in (matches a reset history)
    d = [zeros(k, 1); x(1 : end - k)];
end
