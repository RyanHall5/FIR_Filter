function rampLoopbackTest(cfg)
% rampLoopbackTest  Bring-up test for the STM32 relay. Sends a known ramp
%                   (0,1,2,...) over serial. In 'loopback' mode it also reads
%                   the stream back and compares.
%
%   rampLoopbackTest(cfg)
%
%   Uses cfg.selftest.mode, cfg.selftest.numChunks, cfg.selftest.showPlot,
%   plus cfg.comPort, cfg.baudRate, cfg.chunkSamples and cfg.fs.
%
%   mode 'send'      send only; check the counters in the STM32 debugger
%                    (audioRelayStats).
%   mode 'loopback'  send, read back, compare, plot.
%
%   RESET THE NUCLEO (black button) BEFORE EVERY RUN. The STM32 expects the
%   ramp to start at 0 and counts from there, and a reset also clears any
%   byte misalignment left over from a previous run.
%
%   NOTE: with the FPGA in the loop the returned stream is delayed (one word
%   for the echo design, more once the FIR is in), so an exact comparison will
%   report FAIL; stage 07 (alignLatency) is where that gets handled.

    testMode  = cfg.selftest.mode;
    numChunks = cfg.selftest.numChunks;
    showPlot  = cfg.selftest.showPlot;

    N    = numChunks * cfg.chunkSamples;
    ramp = int16(mod(0:N-1, 32768))';          % column vector, stays below 32768

    s = serialport(cfg.comPort, cfg.baudRate);
    s.Timeout = 5;
    flush(s);

    % --- Send, paced at the real-time sample rate ---
    chunkDuration = cfg.chunkSamples / cfg.fs;
    for c = 1:numChunks
        idx = (c-1)*cfg.chunkSamples + (1:cfg.chunkSamples);
        write(s, ramp(idx), "int16");
        pause(chunkDuration);
    end
    fprintf('Sent %d samples (%d chunks).\n', N, numChunks);

    % --- Read back and compare (loopback mode only) ---
    if strcmp(testMode, 'loopback')
        t0 = tic;
        while s.NumBytesAvailable < 2*N && toc(t0) < 5
            pause(0.01);
        end
        nAvail = floor(s.NumBytesAvailable / 2);
        rx = read(s, min(nAvail, N), "int16")';    % column vector

        fprintf('Received %d of %d samples.\n', numel(rx), N);

        n = min(numel(rx), N);
        bad = find(rx(1:n) ~= ramp(1:n));

        if numel(rx) == N && isempty(bad)
            disp('PASS: returned stream matches the sent ramp exactly.');
        else
            fprintf('FAIL: %d mismatched samples.\n', numel(bad));
            if ~isempty(bad)
                k = bad(1);
                fprintf('  First mismatch at sample %d: sent %d, got %d\n', k, ramp(k), rx(k));
            end
        end

        if showPlot
            figure('Name', 'STM32 loopback test');
            subplot(2,1,1);
            plot(1:n, ramp(1:n), 'b', 1:n, rx(1:n), 'r--');
            legend('sent', 'received'); title('Sent vs received'); xlabel('Sample');
            subplot(2,1,2);
            plot(1:n, double(rx(1:n)) - double(ramp(1:n)));
            title('Received minus sent (should be flat zero)'); xlabel('Sample');
        end
    else
        disp('Send-only mode: check audioRelayStats in the STM32 debugger.');
    end

    clear s;   % release the COM port
end
