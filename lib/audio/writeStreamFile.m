function q = writeStreamFile(x, sampleBits, filename)
% writeStreamFile  Write the scaled composite as the int16 file that gets streamed to the STM32.
%
%   q = writeStreamFile(x, sampleBits, filename)
%
%     x           headroom-scaled floating-point composite
%     sampleBits  fixed-point word width (cfg.sampleBits)
%     filename    output file under data/audio/composite/ (cfg.streamFile)
%     q           the int16 samples that were written (optional output)
%
%   Quantizes exactly the way streamToSTM32 used to (clip, scale by 2^(bits-1)-1, round),
%   so the file the STM32 receives and the vectors the golden model uses are the same samples.
%   File format: raw little-endian int16, no header. Read it back with readStreamFile.

    fullScale = 2^(sampleBits - 1) - 1;

    x = x(:);
    nClipped = nnz(abs(x) > 1);
    if nClipped > 0
        warning('writeStreamFile:clipped', '%d samples exceed full scale and were clipped.', nClipped);
    end
    q = int16(round(max(min(x, 1), -1) * fullScale));

    folder = fileparts(filename);
    if ~isempty(folder) && ~exist(folder, 'dir')
        mkdir(folder);
    end

    fid = fopen(filename, 'w', 'ieee-le');
    if fid < 0
        error('writeStreamFile:openFailed', 'Cannot open %s for writing.', filename);
    end
    cleanup = onCleanup(@() fclose(fid));
    nWritten = fwrite(fid, q, 'int16');
    if nWritten ~= numel(q)
        error('writeStreamFile:shortWrite', 'Wrote %d of %d samples.', nWritten, numel(q));
    end
    fprintf('  Stream file written to %s (%d samples, peak %d)\n', ...
        filename, numel(q), max(abs(double(q))));
end
