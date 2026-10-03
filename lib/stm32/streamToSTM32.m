function streamToSTM32(compositePath, fs, sampleBits, comPort, baudRate, chunkSamples, streamSeconds)
% streamToSTM32  Stream the quantized composite signal to the STM32 over
%                 serial, continuously and paced in real time.
%
%   streamToSTM32(compositePath, fs, sampleBits, comPort, baudRate, chunkSamples, streamSeconds)
%
%   compositePath   - path to composite.wav
%   fs              - expected sample rate (Hz)
%   sampleBits      - quantization bit width (e.g. 16)
%   comPort         - serial port name, e.g. 'COM3'
%   baudRate        - serial baud rate (e.g. 3000000)
%   chunkSamples    - samples per write, matched to the STM32 ring buffer size
%   streamSeconds   - how many seconds to stream (use Inf for the whole file)

    [composite, fsIn] = audioread(compositePath);
    if fsIn ~= fs
        error('Composite sample rate (%d) does not match expected fs (%d)', fsIn, fs);
    end

    fullScale = 2^(sampleBits - 1) - 1;
    clipped   = max(min(composite, 1), -1);
    quantized = int16(round(clipped * fullScale));

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