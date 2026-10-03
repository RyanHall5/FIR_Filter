function y = scaleForHeadroom(x, inPeak)
% scaleForHeadroom  Scale the composite signal so it can never overflow the filter output.
%
%   STATUS: PLACEHOLDER - not implemented yet.
%
%   y = scaleForHeadroom(x, inPeak)
%
%   Planned behaviour:
%     x       floating-point composite signal (|x| <= 1)
%     inPeak  largest safe int16 input peak, from headroomLimit / fixedPointParams (fp.INPUT_PEAK)
%     y       x scaled so max|y| = inPeak / 32767
%
%   Headroom is the project's overflow policy: the core has no saturation logic, so the input
%   must be scaled so the worst-case output (peak * sum|h|) still fits in 16 bits.
%   Called by stage 03 (run_audio_prep) once stage 02 has produced fp.INPUT_PEAK.

    error('scaleForHeadroom:notImplemented', 'scaleForHeadroom is a placeholder and is not implemented yet.');
end
