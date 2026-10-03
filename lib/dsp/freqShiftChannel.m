function y = freqShiftChannel(x, fs, fc, basebandBW)
% freqShiftChannel  Bandlimit a signal to baseband, then shift it up to
%                    a carrier center frequency by mixing with a cosine.
%
%   y = freqShiftChannel(x, fs, fc, basebandBW)
%
%   x           - input signal (column vector), e.g. one normalized song
%   fs          - sample rate in Hz
%   fc          - carrier center frequency in Hz to shift the signal to
%   basebandBW  - baseband bandwidth in Hz (lowpass cutoff before shifting)
%
%   y           - frequency-shifted signal, same length as x

    x = x(:);

    % Bandlimit to baseband BEFORE shifting, so content beyond basebandBW
    % doesn't leak into neighboring channels/guard bands once shifted.
    lpFilt = fir1(200, basebandBW / (fs/2));
    xBase = filter(lpFilt, 1, x);

    % Compensate for the FIR filter's group delay (N/2 samples for an
    % order-N linear-phase filter)
    delay = 100;
    xBase = [xBase(delay+1:end); zeros(delay, 1)];

    % Shift to carrier by mixing with cos(2*pi*fc*t)
    t = (0:length(xBase)-1)' / fs;
    y = xBase .* cos(2*pi*fc*t);
end
