function x = demodChannel(y, fs, fc, basebandBW, filterDelay)
% demodChannel  Bring one filtered channel back to baseband (inverse of freqShiftChannel).
%
%   x = demodChannel(y, fs, fc, basebandBW)
%   x = demodChannel(y, fs, fc, basebandBW, filterDelay)
%
%     y            filtered channel signal returned by the FPGA (column vector)
%     fs           sample rate (Hz)
%     fc           carrier center frequency of the selected channel (Hz)
%     basebandBW   baseband bandwidth (Hz)
%     filterDelay  group delay (samples) of the channel filter that produced y, removed
%                  before mixing (default 0). For the 117-tap linear-phase filter this is
%                  58. It must be removed: the filter delay moves the carrier phase, and
%                  mixing with cos(2*pi*fc*t) then loses most of the signal (for example
%                  at fc = 36 kHz a 58 sample delay is a quarter cycle and the output
%                  would be about zero).
%     x            demodulated baseband audio, ready to listen to or save as .wav
%
%   Steps: remove the filter delay, mix with cos(2*pi*fc*t), lowpass at basebandBW,
%   compensate the lowpass group delay, and double the result (mixing halves the
%   amplitude). Mirrors freqShiftChannel.
%
%   AI note: written by Claude (Anthropic) at the author's request.

    if nargin < 5
        filterDelay = 0;
    end

    y = y(:);

    % Remove the channel filter's delay so the carrier phase matches the mixer
    y = [y(filterDelay+1:end); zeros(filterDelay, 1)];

    % Mix down with cos(2*pi*fc*t)
    t = (0:length(y)-1)' / fs;
    mixed = y .* cos(2*pi*fc*t);

    % Lowpass at basebandBW to remove the image at 2*fc, then compensate the lowpass
    % group delay (N/2 samples for an order-N linear-phase filter), as freqShiftChannel does
    lpFilt = fir1(200, basebandBW / (fs/2));
    xBase = filter(lpFilt, 1, mixed);
    delay = 100;
    xBase = [xBase(delay+1:end); zeros(delay, 1)];

    % Mixing with a cosine halves the amplitude
    x = 2 * xBase;
end
