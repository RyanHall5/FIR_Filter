function [x, fsOut] = loadAndNormalize(filename, targetFs)
% loadAndNormalize  Load an audio file and normalize it to mono at a target sample rate.
%
%   [x, fsOut] = loadAndNormalize(filename, targetFs)
%
%   filename  - path to source audio file (wav, mp3, etc. - anything audioread supports)
%   targetFs  - desired output sample rate in Hz
%
%   x         - column vector of samples, mono, normalized to [-1, 1] float
%   fsOut     - the output sample rate (== targetFs), returned for convenience

    if nargin < 2
        targetFs = 96000;
    end

    [x, fs] = audioread(filename);

    info = audioinfo(filename);
    fprintf('  %s: %d Hz, %d ch, %.1f s (source)\n', ...
        filename, info.SampleRate, info.NumChannels, info.Duration);

    if size(x, 2) > 1
        x = mean(x, 2);
    end

    if fs ~= targetFs
        x = resample(x, targetFs, fs);
    end
    fsOut = targetFs;

    peak = max(abs(x));
    if peak > 1
        x = x / peak;
    end

    fprintf('    -> normalized: %d Hz, mono, %.1f s\n', fsOut, length(x)/fsOut);
end
