function [gain, maxGain, inPeak] = headroomLimit(hq, shift)
% headroomLimit  Worst-case gain of the quantized filters and the largest input
%                peak that is guaranteed not to overflow a 16-bit output.
%
%   [gain, maxGain, inPeak] = headroomLimit(hq, shift)
%
%   hq      - integer coefficients, one column per channel (full N_TAPS length)
%   shift   - output truncation shift (real coefficient = hq / 2^shift)
%
%   gain    - per channel: sum(|h|), the largest |output| / |input| possible
%   maxGain - max over channels
%   inPeak  - floor(32767 / maxGain): input samples with |x| <= inPeak cannot
%             overflow the output of any channel

    gain    = sum(abs(hq), 1) / 2^shift;
    maxGain = max(gain);
    inPeak  = floor(32767 / maxGain);
end
