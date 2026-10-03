function plotSpectrum(x, fs, titleStr)
% plotSpectrum  Plot the frequency spectrum of a signal.
%
%   plotSpectrum(x, fs, titleStr)
%
%   x         - signal (column or row vector)
%   fs        - sample rate in Hz
%   titleStr  - title string for the plot

    pspectrum(x, fs);
    title(titleStr);
end
