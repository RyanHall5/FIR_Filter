function [y, info] = goldenFirSwitch(x, h_half_sets, switchSchedule, shift, coefBits)
% goldenFirSwitch  Golden model with a channel-switch schedule (coefficient set changes mid-stream).
%
%   STATUS: PLACEHOLDER - not implemented yet.
%
%   [y, info] = goldenFirSwitch(x, h_half_sets, switchSchedule, shift, coefBits)
%
%   Planned behaviour:
%     x               int16-range input samples
%     h_half_sets     N_HALF-by-nCh matrix of half coefficient sets (fp.h_half)
%     switchSchedule  [sampleIndex channel] rows; channel_select is latched when a sample is accepted
%     y, info         as goldenFir, plus a mask marking the first N_TAPS-1 outputs after each switch
%                     (they blend two coefficient sets in some architectures and are don't-care)
%   The sample history is NOT reset at a switch (an FIR has no feedback, so no remnants of the
%   old channel remain in it). Only needed if the testbench covers channel switching.

    error('goldenFirSwitch:notImplemented', 'goldenFirSwitch is a placeholder and is not implemented yet.');
end
