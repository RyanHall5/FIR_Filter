function fig = plotFilterResponses(hList, names, fs, titleStr, opts)
% plotFilterResponses  Plot the magnitude responses of several filters on one axis
%                      (on-screen check in the standard MATLAB look).
%
%   plotFilterResponses(hList, names, fs, titleStr)
%   plotFilterResponses(hList, names, fs, titleStr, opts)
%   fig = plotFilterResponses(...)
%
%   AI note: the kHz, band-edge, colour and export options were added by Claude (Anthropic).
%   The poster's Fig. 1 is NOT drawn here: see lib/plot/plotFilterPoster.m (stage 09), which
%   uses the shared poster look and the exact slot size.
%
%   hList     - cell array of coefficient vectors (real-valued)
%   names     - cell array of legend labels, same length as hList
%   fs        - sample rate (Hz)
%   titleStr  - plot title
%   opts      - optional struct, any of:
%                 .nfft       points per response              (default 4096)
%                 .kHz        true = x axis in kHz, else Hz    (default false)
%                 .ylim       [lo hi] in dB                    (default [-100 5])
%                 .edgesHz    vector of band edges (Hz) to mark with dashed lines
%                 .colors     cell of colours, one per filter  (default b, r, g, m, c, k)
%                 .exportBase path without extension: writes <base>.pdf (vector)
%                             and <base>.png (300 dpi)          (default: no export)
%
%   Requires the Signal Processing Toolbox (freqz). Marks band edges with
%   xline, which needs MATLAB R2018b or newer.

    if nargin < 5, opts = struct(); end
    if ~isfield(opts, 'nfft'),    opts.nfft = 4096;       end
    if ~isfield(opts, 'kHz'),     opts.kHz  = false;      end
    if ~isfield(opts, 'ylim'),    opts.ylim = [-100 5];   end
    if ~isfield(opts, 'edgesHz'), opts.edgesHz = [];      end
    if ~isfield(opts, 'colors'),  opts.colors = {'b', 'r', 'g', 'm', 'c', 'k'}; end

    scale  = 1;  unitStr = 'Hz';
    if opts.kHz, scale = 1000; unitStr = 'kHz'; end

    fig = figure('Name', titleStr);
    ax  = axes(fig);
    hold(ax, 'on');

    if ~isempty(opts.edgesHz)
        xline(ax, opts.edgesHz / scale, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1, 'HandleVisibility', 'off');
    end
    for i = 1:numel(hList)
        [H, f] = freqz(hList{i}, 1, opts.nfft, fs);
        plot(ax, f / scale, 20*log10(abs(H) + eps), 'Color', opts.colors{mod(i-1, numel(opts.colors)) + 1}, ...
             'LineWidth', 0.5, 'DisplayName', names{i});
    end
    xlabel(ax, sprintf('Frequency (%s)', unitStr));
    ylabel(ax, 'Magnitude (dB)');
    ylim(ax, opts.ylim);
    grid(ax, 'on');
    title(ax, titleStr);
    legend(ax, 'show');

    if isfield(opts, 'exportBase') && ~isempty(opts.exportBase)
        outDir = fileparts(opts.exportBase);
        if ~isempty(outDir) && ~exist(outDir, 'dir'), mkdir(outDir); end
        exportgraphics(fig, [opts.exportBase '.pdf'], 'ContentType', 'vector', 'BackgroundColor', 'white');
        exportgraphics(fig, [opts.exportBase '.png'], 'Resolution', 300, 'BackgroundColor', 'white');
        fprintf('  wrote %s (.pdf, .png)\n', opts.exportBase);
    end
end
