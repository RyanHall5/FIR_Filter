classdef DemodChannelTest < matlab.unittest.TestCase
% DemodChannelTest  demodChannel must undo freqShiftChannel, including when the signal has
% passed through a linear-phase filter with a 58 sample delay (which moves the carrier phase).
%
% AI note: written by Claude (Anthropic) at the author's request.

    methods (Test)
        function recoversBasebandTones(testCase)
            fs = 96000; bw = 6000;
            t  = (0:19999)' / fs;
            x  = 0.4 * sin(2*pi*500*t) + 0.3 * sin(2*pi*2000*t);   % well inside the 6 kHz baseband

            for fc = [8000 22000 36000]
                y  = freqShiftChannel(x, fs, fc, bw);
                yd = [zeros(58, 1); y(1:end-58)];                   % delay of the 117-tap channel filter
                xr = demodChannel(yd, fs, fc, bw, 58);
                mid = 1000:numel(x)-1000;                           % skip the filter edge effects
                testCase.verifyLessThan(max(abs(xr(mid) - x(mid))), 0.03, ...
                    sprintf('fc = %d Hz', fc));
            end
        end

        function withoutDelayCompensationFails(testCase)
            % Documents why filterDelay matters: at 36 kHz a 58 sample delay is a quarter cycle
            fs = 96000; bw = 6000; fc = 36000;
            t  = (0:19999)' / fs;
            x  = 0.4 * sin(2*pi*500*t);
            y  = freqShiftChannel(x, fs, fc, bw);
            yd = [zeros(58, 1); y(1:end-58)];
            xr = demodChannel(yd, fs, fc, bw);                      % no compensation
            mid = 1000:numel(x)-1000;
            testCase.verifyLessThan(max(abs(xr(mid))), 0.1);
        end
    end
end
