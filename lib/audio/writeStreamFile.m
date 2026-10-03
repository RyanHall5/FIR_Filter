function writeStreamFile(x, sampleBits, filename)
% writeStreamFile  Write the scaled composite as the int16 file that gets streamed to the STM32.
%
%   STATUS: PLACEHOLDER - not implemented yet.
%
%   writeStreamFile(x, sampleBits, filename)
%
%   Planned behaviour:
%     x           headroom-scaled floating-point composite
%     sampleBits  fixed-point word width (cfg.sampleBits)
%     filename    output file under data/audio/composite/
%   Quantizes to int16 exactly the way streamToSTM32 does today, so the file the STM32
%   receives and the vectors the golden model uses are the same samples.

    error('writeStreamFile:notImplemented', 'writeStreamFile is a placeholder and is not implemented yet.');
end
