function streamToSTM32(streamPath, fs, comPort, baudRate, chunkSamples, streamSeconds)
% streamToSTM32  Stream the int16 composite stream file to the STM32 over
%                 serial, continuously and paced in real time.
%
%   streamToSTM32(streamPath, fs, comPort, baudRate, chunkSamples, streamSeconds)
%
%   streamPath      - int16 stream file written by stage 03 (cfg.streamFile)
%   fs              - sample rate (Hz), used for real-time pacing
%   comPort         - serial port name, e.g. 'COM3'
%   baudRate        - serial baud rate (e.g. 3000000)
%   chunkSamples    - samples per write, matched to the STM32 ring buffer size
%   streamSeconds   - how many seconds to stream (use Inf for the whole file)
%
%   The samples are sent exactly as stored: the file is already headroom-scaled and
%   quantized, so what the STM32 receives is what the golden model sees.

    quantized = readStreamFile(streamPath);

    numSamplesToSend = min(round(streamSeconds * fs), length(quantized));
    quantized = quantized(1:numSamplesToSend);

    fprintf('  Streaming %d samples (%.2f s) in chunks of %d\n', ...
        numSamplesToSend, numSamplesToSend/fs, chunkSamples);

    s = serialport(comPort, baudRate);

    chunkDuration = chunkSamples / fs;
    numChunks = ceil(numSamplesToSend / chunkSamples);

    for c = 1:numChunks
        idxStart = (c-1)*chunkSamples + 1;
        idxEnd   = min(c*chunkSamples, numSamplesToSend);
        chunk    = quantized(idxStart:idxEnd);

        write(s, chunk, "int16");
        pause(chunkDuration);

        if mod(c, 100) == 0
            fprintf('    sent chunk %d/%d\n', c, numChunks);
        end
    end

    fprintf('  Done streaming.\n');
    clear s;
end