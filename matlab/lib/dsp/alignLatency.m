function [rxAligned, lag] = alignLatency(rx, ref, maxLag)
% alignLatency  Find and remove the fixed latency between the returned stream and a reference.
%
%   STATUS: PLACEHOLDER - not implemented yet.
%
%   [rxAligned, lag] = alignLatency(rx, ref, maxLag)
%
%   Planned behaviour:
%     rx      samples returned by the STM32/FPGA
%     ref     the expected stream (sent samples, or goldenFir output)
%     maxLag  largest latency to search (samples)
%     lag     latency found (cross-correlation), e.g. 1 for the echo design; for the FIR
%             it includes the filter group delay and pipeline latency
%     rxAligned  rx shifted by lag so it lines up with ref for an exact comparison

    error('alignLatency:notImplemented', 'alignLatency is a placeholder and is not implemented yet.');
end
