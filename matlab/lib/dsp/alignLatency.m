function [rxAligned, lag] = alignLatency(rx, ref, maxLag)
% alignLatency  Find and remove the fixed latency between the returned stream and a reference.
%
%   [rxAligned, lag] = alignLatency(rx, ref, maxLag)
%
%     rx         samples returned by the STM32/FPGA
%     ref        the expected stream (the sent samples, or the goldenFir output)
%     maxLag     largest latency to search (samples)
%     lag        latency found: rx(k + lag) matches ref(k). 1 for the echo design; for
%                the FIR it includes the filter group delay and pipeline latency
%     rxAligned  rx(lag+1:end), so rxAligned(i) lines up with ref(i)
%
%   The lag is the one with the most EXACT sample matches over a window taken from the
%   middle of the stream (the start is often silence, where every lag matches). This
%   suits bit-exact hardware; it is not a cross-correlation for noisy data.
%   Warns if no lag matches at least half the window.

    rx  = rx(:);
    ref = ref(:);

    win = min([4096, numel(ref) - maxLag - 1, numel(rx) - maxLag - 1]);
    if win < 16
        error('alignLatency:tooShort', 'Streams are too short to search a lag of up to %d.', maxLag);
    end
    s0 = max(1, floor(numel(ref)/2) - floor(win/2));   % window start in ref

    best = -1;
    lag  = 0;
    for L = 0:maxLag
        i1 = s0 + L;
        if i1 + win - 1 > numel(rx), break; end
        matches = sum(rx(i1:i1+win-1) == ref(s0:s0+win-1));
        if matches > best
            best = matches;
            lag  = L;
        end
    end

    if best < win/2
        warning('alignLatency:noMatch', ...
            'Best lag (%d) matches only %d of %d samples; the streams may not be aligned or not exact.', ...
            lag, best, win);
    end

    rxAligned = rx(lag+1:end);
end
