function composite = generateComposite(songs, normDir, outDir, fc, basebandBW, fs)
% generateComposite  Load normalized songs, pad to equal length, frequency-shift
%                     each to its assigned channel, and sum into one composite signal.
%
%   composite = generateComposite(songs, normDir, outDir, fc, basebandBW, fs)
%
%   songs       - cell array of song base names, e.g. {'song1','song2','song3'}
%   normDir     - folder containing '<song>_norm.wav' files
%   outDir      - folder to write composite.wav into
%   fc          - vector of carrier center frequencies (Hz), one per song
%   basebandBW  - baseband bandwidth per channel (Hz)
%   fs          - expected sample rate (Hz)

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    n = numel(songs);
    x = cell(1, n);
    fsAll = zeros(1, n);
    for i = 1:n
        [x{i}, fsAll(i)] = audioread(fullfile(normDir, [songs{i} '_norm.wav']));
    end
    if any(fsAll ~= fs)
        error('One or more normalized songs do not match expected fs (%d)', fs);
    end

    % Pad all songs to the longest length with silence, so nothing gets cut
    maxLen = max(cellfun(@length, x));
    for i = 1:n
        padLen = maxLen - length(x{i});
        if padLen > 0
            x{i} = [x{i}; zeros(padLen, 1)];
        end
    end
    fprintf('  Padded all songs to %.1f s (%d samples)\n', maxLen/fs, maxLen);

    % Frequency-shift each song to its assigned channel
    shifted = cell(1, n);
    for i = 1:n
        shifted{i} = freqShiftChannel(x{i}, fs, fc(i), basebandBW);
    end

    % Sum into composite signal
    composite = shifted{1};
    for i = 2:n
        composite = composite + shifted{i};
    end

    peak = max(abs(composite));
    if peak > 1
        composite = composite / peak;
        fprintf('  Composite peak exceeded 1, rescaled by %.3f\n', 1/peak);
    end

    audiowrite(fullfile(outDir, 'composite.wav'), composite, fs);
    fprintf('  Composite written to %s\n', fullfile(outDir, 'composite.wav'));
end
