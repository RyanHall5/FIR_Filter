function [h, n, nEst] = designChannelFilter(c, fs, rippleDb, stopDb, n)
% designChannelFilter  Equiripple (Parks-McClellan) design of ONE channel-select
%                      filter, with a symmetric (odd tap count) result.
%
%   [h, n, nEst] = designChannelFilter(c, fs, rippleDb, stopDb)      designs at the
%                  firpmord estimate (rounded up to an even order)
%   [h, n, nEst] = designChannelFilter(c, fs, rippleDb, stopDb, n)   designs at order n
%
%   c         - one element of channelBands(cfg)
%   fs        - sample rate (Hz)
%   rippleDb  - allowed passband ripple, peak-to-peak (dB)
%   stopDb    - stopband attenuation target (dB)
%   n         - filter order (taps - 1), must be even
%
%   h         - coefficients (row vector, n+1 taps)
%   nEst      - the firpmord order estimate (even)
%
%   Requires the Signal Processing Toolbox (firpmord, firpm).

    dp = (10^(rippleDb/20) - 1) / (10^(rippleDb/20) + 1);   % peak-to-peak ripple -> deviation
    ds = 10^(-stopDb/20);

    dev = zeros(1, numel(c.a));
    dev(c.a == 1) = dp;
    dev(c.a == 0) = ds;

    [nEst, fo, ao, w] = firpmord(c.f, c.a, dev, fs);
    nEst = nEst + mod(nEst, 2);          % even order = odd tap count (symmetric, type I)

    if nargin < 5
        n = nEst;
    end
    h = firpm(n, fo, ao, w);
end
