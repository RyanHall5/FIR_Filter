function [hq, shift] = quantizeCoefs(h, nbits, shift)
% QUANTIZE_COEFS  Round filter coefficients to signed nbits integers.
%   [hq, shift] = quantizeCoefs(h, nbits)         picks the largest power-of-two
%                                                   scale (2^shift) that fits nbits
%   [hq, shift] = quantizeCoefs(h, nbits, shift)  uses a shift you supply
%
% The real-valued coefficient is hq / 2^shift. In hardware, undoing the scale is
% just dropping the lowest 'shift' bits of the accumulator.
    maxInt = 2^(nbits - 1) - 1;
    if nargin < 3
        shift = floor(log2(maxInt / max(abs(h))));
    end
    hq = round(h * 2^shift);
    assert(all(hq >= -maxInt - 1 & hq <= maxInt), ...
           'quantizeCoefs: shift %d does not fit in %d bits', shift, nbits);
end
