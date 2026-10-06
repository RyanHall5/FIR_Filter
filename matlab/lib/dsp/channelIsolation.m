function m = channelIsolation(y, fs, cfg, selected)
% channelIsolation  Measure how much of the other channels leaked into a filtered output.
%
%   STATUS: PLACEHOLDER - not implemented yet.
%
%   m = channelIsolation(y, fs, cfg, selected)
%
%   Planned behaviour:
%     y         filtered output captured from the FPGA
%     fs        sample rate (Hz)
%     cfg       config() (uses fc, basebandBW)
%     selected  index of the selected channel
%     m         struct with the in-band power of the selected channel, the power in each
%               other channel's band, and the isolation (dB) between them
%   This is the headline measurement for the three-song demo.

    error('channelIsolation:notImplemented', 'channelIsolation is a placeholder and is not implemented yet.');
end
