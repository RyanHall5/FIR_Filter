function fig = plotFilterResponses(hList, names, fs, titleStr, opts)
% plotFilterResponses  Plot the magnitude responses of several filters on one axis.
%
%   plotFilterResponses(hList, names, fs, titleStr)
%   plotFilterResponses(hList, names, fs, titleStr, opts)
%   fig = plotFilterResponses(...)
%
%   AI note: the poster style and export options were added by Claude (Anthropic).
%
%   hList     - cell array of coefficient vectors (real-valued)
%   names     - cell array of legend labels, same length as hList
%   fs        - sample rate (Hz)
%   titleStr  - plot title (in the poster style it names the figure window only,
%               because the poster panel carries the title)
%   opts      - optional struct, any of:
%                 .nfft       points per response              (default 4096)
%                 .kHz        true = x axis in kHz, else Hz    (default false)
%                 .ylim       [lo hi] in dB                    (default [-100 5])
%                 .edgesHz    vector of band edges (Hz) to mark with dashed lines
%                 .style      'default' or 'poster'            (default 'default')
%                 .colors     cell of RGB triplets, one per filter (poster default:
%                             three navy shades, told apart by lightness)
%                 .font       font name, poster style          (default 'IBM Plex Sans')
%                 .fontSize   axis font size in pt, poster     (default 24)
%                 .keyFontSize legend font size in pt, poster  (default 20)
%                 .figSize    [w h] in inches, poster          (default [7.6 3.6])
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
    if ~isfield(opts, 'style'),   opts.style = 'default'; end
    poster = strcmpi(opts.style, 'poster');

    scale  = 1;  unitStr = 'Hz';
    if opts.kHz, scale = 1000; unitStr = 'kHz'; end

    if poster
        if ~isfield(opts, 'colors')
            opts.colors = {[14 27 44] / 255, [62 106 154] / 255, [143 179 217] / 255};  % navy, steel, light blue
        end
        if ~isfield(opts, 'font'),        opts.font = 'IBM Plex Sans'; end
        if ~isfield(opts, 'fontSize'),    opts.fontSize = 24;          end
        if ~isfield(opts, 'keyFontSize'), opts.keyFontSize = 20;       end
        if ~isfield(opts, 'figSize'),     opts.figSize = [7.6 3.6];    end
        fn = opts.font;
        if ~any(strcmpi(listfonts, fn))
            warning('plotFilterResponses:font', 'Font "%s" not installed; using Helvetica.', fn);
            fn = 'Helvetica';
        end
        fig = figure('Name', titleStr, 'Color', 'w', 'Units', 'inches', 'Position', [1 1 opts.figSize]);
        lw  = 3;
    else
        if ~isfield(opts, 'colors')
            opts.colors = {'b', 'r', 'g', 'm', 'c', 'k'};
        end
        fig = figure('Name', titleStr);
        lw  = 0.5;
    end
    ax = axes(fig);
    hold(ax, 'on');

    if ~isempty(opts.edgesHz)
        edgeCol = [0.5 0.5 0.5];
        if poster, edgeCol = [154 163 174] / 255; end
        xline(ax, opts.edgesHz / scale, '--', 'Color', edgeCol, 'LineWidth', 1, 'HandleVisibility', 'off');
    end
    for i = 1:numel(hList)
        [H, f] = freqz(hList{i}, 1, opts.nfft, fs);
        plot(ax, f / scale, 20*log10(abs(H) + eps), 'Color', opts.colors{mod(i-1, numel(opts.colors)) + 1}, ...
             'LineWidth', lw, 'DisplayName', names{i});
    end
    xlabel(ax, sprintf('Frequency (%s)', unitStr));
    ylabel(ax, 'Magnitude (dB)');
    ylim(ax, opts.ylim);
    grid(ax, 'on');

    if poster
        xlim(ax, [0, fs / 2 / scale]);
        muted = [90 98 112] / 255;  ink = [31 35 40] / 255;
        set(ax, 'FontName', fn, 'FontSize', opts.fontSize, 'LineWidth', 1.25, 'TickDir', 'out', ...
            'XColor', muted, 'YColor', muted, 'GridColor', [208 213 219] / 255, 'GridAlpha', 1, ...
            'LabelFontSizeMultiplier', 1, 'Box', 'off', 'Layer', 'top');
        ax.XLabel.Color = ink;
        ax.YLabel.Color = ink;
        legend(ax, 'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off', ...
            'FontName', fn, 'FontSize', opts.keyFontSize, 'TextColor', muted);
    else
        title(ax, titleStr);
        legend(ax, 'show');
    end

    if isfield(opts, 'exportBase') && ~isempty(opts.exportBase)
        outDir = fileparts(opts.exportBase);
        if ~isempty(outDir) && ~exist(outDir, 'dir'), mkdir(outDir); end
        exportgraphics(fig, [opts.exportBase '.pdf'], 'ContentType', 'vector', 'BackgroundColor', 'white');
        exportgraphics(fig, [opts.exportBase '.png'], 'Resolution', 300, 'BackgroundColor', 'white');
        fprintf('  wrote %s (.pdf, .png)\n', opts.exportBase);
    end
end
