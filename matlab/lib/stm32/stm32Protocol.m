function p = stm32Protocol()
% stm32Protocol  Command codes and frame layout for the MATLAB <-> STM32 serial protocol.
%
%   STATUS: PLACEHOLDER - not implemented yet.
%
%   p = stm32Protocol()
%
%   Planned behaviour: the ONE place that defines the protocol, used by both sides of the
%   MATLAB code (sendCoefficients, setChannel, streamToSTM32):
%     p.CMD_COEFFS, p.CMD_CHANNEL, p.CMD_STREAM  command bytes
%     frame layout (header, set number, payload length, payload, checksum if any)
%   The layout waits on the STM32 firmware protocol, which has not been designed yet.
%   Keep the firmware constants in sync with this file.

    error('stm32Protocol:notImplemented', 'stm32Protocol is a placeholder and is not implemented yet.');
end
