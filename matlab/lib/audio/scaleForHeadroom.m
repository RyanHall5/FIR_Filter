function y = scaleForHeadroom(x, inPeak)
% scaleForHeadroom  Scale the composite signal so it can never overflow the filter output.
%
%   y = scaleForHeadroom(x, inPeak)
%
%     x       floating-point composite signal (|x| <= 1)
%     inPeak  largest safe int16 input peak, from headroomLimit / fixedPointParams (fp.INPUT_PEAK)
%     y       x scaled so max|y| = inPeak / 32767
%
%   Headroom is the project's overflow policy: the core has no saturation logic, so the input
%   must be scaled so the worst-case output (peak * sum|h|) still fits in 16 bits.
%   Called by stage 03 (run_audio_prep) once stage 02 has produced fp.INPUT_PEAK.
%
%   The scale is applied up or down as needed, so the result always peaks at exactly
%   inPeak counts once quantized by writeStreamFile.

    fullScale = 2^15 - 1;   % int16 full scale; matches writeStreamFile at 16 bits

    if ~isnumeric(inPeak) || ~isscalar(inPeak) || inPeak <= 0 || inPeak > fullScale
        error('scaleForHeadroom:badPeak', 'inPeak must be a scalar in (0, %d].', fullScale);
    end

    peak = max(abs(x(:)));
    if peak == 0
        error('scaleForHeadroom:silent', 'Input signal is all zeros; cannot scale.');
    end

    y = x * ((inPeak / fullScale) / peak);
end
