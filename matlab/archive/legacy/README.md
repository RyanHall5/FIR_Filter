Superseded code, kept so nothing is lost. Not on the MATLAB path and not used by any stage.

- designCoefficients.m - original floating-point 101-tap bandpass design for every channel
  (cfg.numTaps, which no longer exists). Replaced by stages 01 and 02 (lib/dsp/channelBands,
  designChannelFilter, findMinTaps and lib/fixedpoint/fixedPointParams).
