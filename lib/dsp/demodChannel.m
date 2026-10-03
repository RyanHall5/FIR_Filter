function x = demodChannel(y, fs, fc, basebandBW)
% demodChannel  Bring one filtered channel back to baseband (inverse of freqShiftChannel).
%
%   STATUS: PLACEHOLDER - not implemented yet.
%
%   x = demodChannel(y, fs, fc, basebandBW)
%
%   Planned behaviour:
%     y           filtered channel signal returned by the FPGA (column vector)
%     fs          sample rate (Hz)
%     fc          carrier center frequency of the selected channel (Hz)
%     basebandBW  baseband bandwidth (Hz)
%     x           demodulated baseband audio, ready to listen to or save as .wav
%   Mix with cos(2*pi*fc*t), lowpass at basebandBW, correct the gain (mixing halves the
%   amplitude) and compensate the lowpass group delay, mirroring freqShiftChannel.

    error('demodChannel:notImplemented', 'demodChannel is a placeholder and is not implemented yet.');
end
