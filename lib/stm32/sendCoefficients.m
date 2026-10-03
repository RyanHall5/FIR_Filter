function sendCoefficients(s, fp)
% sendCoefficients  Send the quantized half coefficient sets to the STM32 (which forwards them to the FPGA).
%
%   STATUS: PLACEHOLDER - not implemented yet.
%
%   sendCoefficients(s, fp)
%
%   Planned behaviour:
%     s    open serial link (openLink)
%     fp   fixedPointParams result; sends fp.h_half (N_HALF words per set, COEF_W bits each)
%          for every channel using the frame layout in stm32Protocol
%   Waits on the firmware protocol design.

    error('sendCoefficients:notImplemented', 'sendCoefficients is a placeholder and is not implemented yet.');
end
