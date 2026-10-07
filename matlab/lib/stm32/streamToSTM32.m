function [sent, rx] = streamToSTM32(streamPath, fs, comPort, baudRate, chunkSamples, streamSeconds, drainSeconds)
% streamToSTM32  Stream the int16 composite stream file to the STM32 over serial,
%                paced in real time, and capture the stream the STM32 sends back.
%
%   [sent, rx] = streamToSTM32(streamPath, fs, comPort, baudRate, chunkSamples, streamSeconds, drainSeconds)
%
%   streamPath      - int16 stream file written by stage 03 (cfg.streamFile)
%   fs              - sample rate (Hz), used for real-time pacing
%   comPort         - serial port name, e.g. 'COM4'
%   baudRate        - serial baud rate
%   chunkSamples    - samples per write, matched to the STM32 buffer size
%   streamSeconds   - how many seconds to stream (use Inf for the whole file)
%   drainSeconds    - how long to keep reading after the last write (default 2)
%
%   sent - exactly what was written, as a column. The last chunk is zero-padded to
%          a full chunkSamples, because the STM32 only processes whole frames.
%   rx   - everything read back, as a column (the returned stream, delayed by the
%          FPGA/relay latency). Compare with alignLatency.
%
%   The samples are sent exactly as stored: the file is already headroom-scaled and
%   quantized, so what the STM32 receives is what the golden model sees.
%   RESET THE NUCLEO (and re-program or reset the FPGA) BEFORE EVERY RUN.

    if nargin < 7, drainSeconds = 2; end

    quantized = readStreamFile(streamPath);
    numSamplesToSend = min(round(streamSeconds * fs), length(quantized));
    quantized = quantized(1:numSamplesToSend);

    numChunks = ceil(numSamplesToSend / chunkSamples);
    total     = numChunks * chunkSamples;
    sent      = [quantized(:); zeros(total - numSamplesToSend, 1, 'int16')];

    fprintf('  Streaming %d samples (%.2f s) in %d chunks of %d (last chunk padded with %d zeros)\n', ...
        numSamplesToSend, numSamplesToSend/fs, numChunks, chunkSamples, total - numSamplesToSend);

    s = serialport(comPort, baudRate);
    s.Timeout = 5;
    flush(s);

    rx  = zeros(total, 1, 'int16');
    nRx = 0;
    chunkDuration = chunkSamples / fs;

    for c = 1:numChunks
        idx = (c-1)*chunkSamples + (1:chunkSamples);
        write(s, sent(idx), "int16");
        pause(chunkDuration);
        [rx, nRx] = drainPort(s, rx, nRx);

        if mod(c, 100) == 0
            fprintf('    sent chunk %d/%d (received %d samples)\n', c, numChunks, nRx);
        end
    end

    % Wait for the tail of the returned stream.
    t0 = tic;
    while nRx < total && toc(t0) < drainSeconds
        pause(0.01);
        [rx, nRx] = drainPort(s, rx, nRx);
    end

    rx = rx(1:nRx);
    fprintf('  Done streaming. Sent %d samples, received %d.\n', total, nRx);
    clear s;
end

function [rx, nRx] = drainPort(s, rx, nRx)
% Read whatever whole int16 samples are waiting; a stray odd byte stays buffered.
    nAvail = floor(s.NumBytesAvailable / 2);
    if nAvail > 0
        d    = read(s, nAvail, "int16")';
        take = min(nAvail, numel(rx) - nRx);
        rx(nRx+1:nRx+take) = d(1:take);
        nRx  = nRx + take;
    end
end
