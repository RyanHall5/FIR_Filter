function r = findMinTaps(c, fs, stopDb, rippleDb, coefBits, searchBack, searchFwd)
% findMinTaps  Smallest filter order whose QUANTIZED response meets the spec.
%
%   r = findMinTaps(c, fs, stopDb, rippleDb, coefBits, searchBack, searchFwd)
%
%   Starts searchBack taps below the firpmord estimate and steps up by 2 until
%   the coefBits-quantized filter meets both the stopband and ripple targets,
%   or gives up searchFwd taps above the estimate.
%
%   r.taps   number of taps found (NaN if the spec was not met)
%   r.h      unquantized coefficients at that order
%   r.hq     integer coefficients (coefBits wide)
%   r.shift  quantization shift (real coefficient = hq / 2^shift)
%   r.As_q   achieved stopband attenuation with quantized coefficients (dB)
%   r.Rp_q   achieved passband ripple with quantized coefficients (dB, p-p)
%
%   A "not met" result usually means the coefficient width sets a floor that
%   more taps cannot fix.

    r = struct('taps', NaN, 'h', [], 'hq', [], 'shift', [], 'As_q', [], 'Rp_q', []);

    [~, n0] = designChannelFilter(c, fs, rippleDb, stopDb);   % second output: even order estimate
    nStart = max(n0 - searchBack, 10);
    nStart = nStart + mod(nStart, 2);

    for n = nStart : 2 : (n0 + searchFwd)
        h = designChannelFilter(c, fs, rippleDb, stopDb, n);
        [hq, shift] = quantizeCoefs(h, coefBits);
        [As_q, Rp_q] = measureResponse(hq / 2^shift, c, fs);
        if As_q >= stopDb && Rp_q <= rippleDb
            r.taps  = n + 1;
            r.h     = h;
            r.hq    = hq;
            r.shift = shift;
            r.As_q  = As_q;
            r.Rp_q  = Rp_q;
            return;
        end
    end
end
