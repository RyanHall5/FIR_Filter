function q = readStreamFile(filename)
% readStreamFile  Read the int16 stream file written by writeStreamFile.
%
%   q = readStreamFile(filename)
%
%   Returns a column vector of int16 samples. This is the single definition of what
%   the STM32 receives, used by streamToSTM32 and by the golden model (stage 04).

    fid = fopen(filename, 'r', 'ieee-le');
    if fid < 0
        error('readStreamFile:openFailed', ...
            'Cannot open %s. Run stage 03 (run_audio_prep) first.', filename);
    end
    cleanup = onCleanup(@() fclose(fid));
    q = fread(fid, Inf, 'int16=>int16');
end
