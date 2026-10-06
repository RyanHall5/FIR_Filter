function setChannel(s, channel)
% setChannel  Tell the FPGA which channel to select (channel_select).
%
%   STATUS: PLACEHOLDER - not implemented yet.
%
%   setChannel(s, channel)
%
%   Planned behaviour: send the channel-select command (stm32Protocol) for channel 1..3.
%   The core latches channel_select when it accepts a sample, so a change takes effect between
%   samples. Waits on the firmware protocol design.

    error('setChannel:notImplemented', 'setChannel is a placeholder and is not implemented yet.');
end
