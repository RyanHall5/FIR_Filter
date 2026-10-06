function [As_dB, Rp_dB] = measureResponse(h, c, fs)
% measureResponse  Worst-case stopband attenuation and passband ripple
%                  (peak-to-peak) of a filter, on a dense frequency grid.
%
%   [As_dB, Rp_dB] = measureResponse(h, c, fs)
%
%   h   - filter coefficients (real-valued, i.e. already divided by 2^shift)
%   c   - one element of channelBands(cfg) (uses c.pass and c.stop)
%   fs  - sample rate (Hz)
%
%   Requires the Signal Processing Toolbox (freqz).

    [H, f] = freqz(h, 1, 32768, fs);
    mag = abs(H);
    inStop = false(size(f));
    for k = 1:size(c.stop, 1)
        inStop = inStop | (f >= c.stop(k, 1) & f <= c.stop(k, 2));
    end
    inPass = (f >= c.pass(1)) & (f <= c.pass(2));
    As_dB = -20 * log10(max(mag(inStop)));
    Rp_dB = 20 * log10(max(mag(inPass))) - 20 * log10(min(mag(inPass)));
end
