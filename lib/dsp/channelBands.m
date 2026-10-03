function ch = channelBands(cfg)
% channelBands  Build the band-edge description of every channel filter from
%               the frequency plan in config().
%
%   ch = channelBands(cfg)
%
%   Uses cfg.fc, cfg.basebandBW, cfg.guardBW and cfg.fs. Returns a struct array
%   (one element per channel) with fields:
%     .name  label, e.g. 'ch2 (bandpass)'
%     .f     band edges between regions, for firpmord (Hz)
%     .a     desired amplitude in each region (1 = pass, 0 = stop)
%     .pass  [lo hi] occupied band, used to measure passband ripple (Hz)
%     .stop  rows of [lo hi] stopband regions, used to measure attenuation (Hz)
%
%   ASSUMPTION: the regions outside the outermost channels (below the first,
%   above the last) are empty, so the first channel is a lowpass and the last
%   is a highpass. This avoids spending taps on transition bands that guard
%   nothing. Needs at least two channels.

    fc = cfg.fc;  bw = cfg.basebandBW;  g = cfg.guardBW;  fs = cfg.fs;
    n  = numel(fc);
    assert(n >= 2, 'channelBands: needs at least two channels');

    passLow  = fc - bw;
    passHigh = fc + bw;

    for i = 1:n
        if i == 1
            nm   = sprintf('ch%d (lowpass)', i);
            f    = [passHigh(i), passHigh(i) + g];
            a    = [1 0];
            stop = [passHigh(i) + g, fs/2];
        elseif i == n
            nm   = sprintf('ch%d (highpass)', i);
            f    = [passLow(i) - g, passLow(i)];
            a    = [0 1];
            stop = [0, passLow(i) - g];
        else
            nm   = sprintf('ch%d (bandpass)', i);
            f    = [passLow(i) - g, passLow(i), passHigh(i), passHigh(i) + g];
            a    = [0 1 0];
            stop = [0, passLow(i) - g; passHigh(i) + g, fs/2];
        end
        ch(i).name = nm;
        ch(i).f    = f;
        ch(i).a    = a;
        ch(i).pass = [passLow(i), passHigh(i)];
        ch(i).stop = stop;
    end
end
