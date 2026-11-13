function k = posterKit(cfg)
% posterKit  One shared look for every chart on the poster.
%
%   k = posterKit(cfg)
%
%   AI note: written by Claude (Anthropic) for Ryan Hall's FIR_Filter project.
%
%   Returns a struct of function handles that plotPpa and plotFilterPoster draw with, so
%   all poster charts share fonts, colours, margins and export settings (cfg.poster).
%
%   How the layout stays predictable:
%     * A figure is created at the exact size of its slot on the poster, in inches
%       (poster canvas: 96 px = 1 in), so font sizes are real point sizes in print.
%     * Axes get a fixed position in inches. Nothing depends on MATLAB's automatic
%       layout, legend placement or tight cropping.
%     * The header row (what is plotted, on the left) and the colour key (on the right)
%       are drawn on an invisible overlay axes whose data units are figure inches.
%     * Charts carry no title or caption: the poster card supplies both.
%     * Export uses print with a fixed paper size, so the PNG is exactly
%       size x cfg.poster.exportDpi pixels (exportgraphics would crop it).
%     * Graphics objects are handled with get/set and 'Parent', which runs in every
%       MATLAB release and in GNU Octave (used to test this file).
%
%   k.st                          the style struct (cfg.poster plus the resolved font name)
%   fig = k.newFigure(name, sizeIn)
%   ax  = k.newAxes(fig, posIn)                     posIn = [left bottom width height], inches
%   ov  = k.overlay(fig)                            call after the data axes exist
%   k.lanesAxis(ax, lanes)                          evenly spaced lane counts + x title
%   k.xTitle(ax, str, dropIn)                       x-axis title, baseline dropIn below the axis
%                                                   (default cfg.poster.xTitleDropIn)
%   k.yAxis(ax, lim, ticks, labels)
%   k.header(ov, xIn, yIn, boldStr, plainStr)       boldStr may be ''
%   k.keyRow(ov, xRightIn, yIn, items)              horizontal key, right-aligned
%   k.keyColumn(ov, xRightIn, yTopIn, items)        vertical key in the small font, right-aligned
%       items: struct array with fields color, label, kind ('bar', 'line', 'o' or 's')
%   k.series(ax, x, y, color, marker)               line with white-ringed markers
%   k.valueLabel(ax, x, y, str, where, gapIn)       where: 'above' (default), 'below', 'aboveLeft'
%   k.note(ax, x, y, str, ...)                      small muted text in data units
%   yy = k.yShift(ax, y, dIn)                       y moved by dIn inches (linear or log axis)
%   k.export(fig, outDir, name)                     <name>.png at the exact slot size

    st = cfg.poster;
    st.fontName = pickFont(st.font);

    k.st         = st;
    k.newFigure  = @(name, sizeIn) newFigure(name, sizeIn);
    k.newAxes    = @(fig, posIn) newAxes(fig, posIn, st);
    k.overlay    = @(fig) newOverlay(fig);
    k.lanesAxis  = @(ax, lanes) lanesAxis(ax, lanes, st);
    k.xTitle     = @(ax, str, varargin) xTitle(ax, str, st, varargin{:});
    k.yAxis      = @(ax, lim, ticks, labels) set(ax, 'YLim', lim, 'YTick', ticks, 'YTickLabel', labels);
    k.header     = @(ov, xIn, yIn, boldStr, plainStr) header(ov, xIn, yIn, boldStr, plainStr, st);
    k.keyRow     = @(ov, xRightIn, yIn, items) keyRow(ov, xRightIn, yIn, items, st);
    k.keyColumn  = @(ov, xRightIn, yTopIn, items) keyColumn(ov, xRightIn, yTopIn, items, st);
    k.series     = @(ax, x, y, col, mk) series(ax, x, y, col, mk, st);
    k.valueLabel = @(ax, x, y, str, varargin) valueLabel(ax, x, y, str, st, varargin{:});
    k.note       = @(ax, x, y, str, varargin) note(ax, x, y, str, st, varargin{:});
    k.yShift     = @(ax, y, dIn) yShift(ax, y, dIn);
    k.export     = @(fig, outDir, name) exportFig(fig, outDir, name, st);
end

% -------------------------------------------------------------------------
function fig = newFigure(name, sizeIn)
% A white figure exactly sizeIn = [width height] inches, on screen and on paper
    fig = figure('Name', name, 'NumberTitle', 'off', 'WindowStyle', 'normal', 'Color', 'w', ...
        'Units', 'inches', 'Position', [0.5, 0.5, sizeIn], ...
        'PaperUnits', 'inches', 'PaperSize', sizeIn, 'PaperPosition', [0, 0, sizeIn], ...
        'InvertHardcopy', 'off');
    set(fig, 'UserData', struct('sizeIn', sizeIn));
    drawnow;
    got = get(fig, 'Position');
    got = got(3:4);
    if any(abs(got - sizeIn) > 0.03)
        warning('posterKit:figureSize', ...
            ['Figure "%s" is %.2f x %.2f in on screen instead of %.2f x %.2f in (screen too small, ' ...
             'or the figure is docked). The exported PNG still has the right size, but check it.'], ...
            name, got(1), got(2), sizeIn(1), sizeIn(2));
    end
end

function ax = newAxes(fig, posIn, st)
    c  = st.colors;
    ax = axes('Parent', fig, 'Units', 'inches', 'Position', posIn);
    hold(ax, 'on');
    set(ax, 'FontName', st.fontName, 'FontSize', st.fontSize, 'LineWidth', 1, 'Color', 'w', ...
        'TickDir', 'out', 'TickLength', [0.06, 0.06] / max(posIn(3:4)), 'Box', 'off', ...
        'XColor', c.muted, 'YColor', c.muted, 'TickLabelInterpreter', 'none', ...
        'XGrid', 'off', 'YGrid', 'on', 'GridColor', c.grid, 'GridAlpha', 1, 'GridLineStyle', '-', ...
        'XMinorTick', 'off', 'YMinorTick', 'off', 'XMinorGrid', 'off', 'YMinorGrid', 'off', ...
        'Layer', 'bottom');
end

function ov = newOverlay(fig)
% Invisible axes over the whole figure; its data units are inches from the lower-left corner
    sz = get(fig, 'UserData');
    sz = sz.sizeIn;
    ov = axes('Parent', fig, 'Units', 'inches', 'Position', [0, 0, sz], 'Visible', 'off', ...
        'HitTest', 'off', 'PickableParts', 'none', 'Clipping', 'off');
    hold(ov, 'on');
    set(ov, 'XLim', [0, sz(1)], 'YLim', [0, sz(2)]);
end

function lanesAxis(ax, lanes, st)
% Lane counts at evenly spaced positions 1..n. No tick marks: the lane numbers and the
% horizontal grid lines already mark the positions.
    n = numel(lanes);
    set(ax, 'XLim', [0.5, n + 0.5], 'XTick', 1:n, 'XTickLabel', compose('%d', lanes(:)), ...
        'TickLength', [0, 0]);
    xTitle(ax, 'Number of lanes', st);
end

function xTitle(ax, str, st, dropIn)
% X-axis title centred under the axes, baseline dropIn below the axis line
    if nargin < 4, dropIn = st.xTitleDropIn; end
    pos = get(ax, 'Position');   % inches
    text(pos(3) / 2, -dropIn, str, 'Parent', ax, 'Units', 'inches', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'baseline', ...
        'FontName', st.fontName, 'FontSize', st.fontSize, 'Color', st.colors.text, ...
        'Interpreter', 'none', 'Clipping', 'off');
end

function header(ov, xIn, yIn, boldStr, plainStr, st)
% Header row: optional bold lead-in (ink) followed by what the y axis measures (muted)
    c = st.colors;
    if ~isempty(boldStr)
        t = text(xIn, yIn, boldStr, 'Parent', ov, 'FontWeight', 'bold', 'Color', c.text, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
            'FontName', st.fontName, 'FontSize', st.fontSize, 'Interpreter', 'none');
        xIn = xIn + textWidth(t) + 0.09;
    end
    text(xIn, yIn, plainStr, 'Parent', ov, 'Color', c.muted, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'FontName', st.fontName, 'FontSize', st.fontSize, 'Interpreter', 'none');
end

function keyRow(ov, xRightIn, yIn, items, st)
% Horizontal colour key, built right to left so it ends exactly at xRightIn
    x = xRightIn;
    for i = numel(items):-1:1
        t = text(x, yIn, items(i).label, 'Parent', ov, 'Color', st.colors.text, ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
            'FontName', st.fontName, 'FontSize', st.fontSize, 'Interpreter', 'none');
        xs = x - textWidth(t) - st.keyTextGapIn - st.swatchIn;     % left edge of the swatch
        swatch(ov, xs, yIn, items(i), st);
        x  = xs - st.keyItemGapIn;
    end
end

function keyColumn(ov, xRightIn, yTopIn, items, st)
% Vertical colour key in the small font; the widest row ends at xRightIn
    wMax = 0;
    for i = 1:numel(items)
        t = text(0, 0, items(i).label, 'Parent', ov, 'FontName', st.fontName, ...
            'FontSize', st.noteFontSize, 'Interpreter', 'none');
        wMax = max(wMax, textWidth(t));
        delete(t);
    end
    xs = xRightIn - wMax - st.keyTextGapIn - st.swatchIn;
    for i = 1:numel(items)
        y = yTopIn - (i - 1) * st.keyRowPitchIn;
        swatch(ov, xs, y, items(i), st);
        text(xs + st.swatchIn + st.keyTextGapIn, y, items(i).label, 'Parent', ov, 'Color', st.colors.text, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
            'FontName', st.fontName, 'FontSize', st.noteFontSize, 'Interpreter', 'none');
    end
end

function w = textWidth(t)
% Width of a text object on the overlay axes, in inches (its data units)
    e = get(t, 'Extent');
    w = e(3);
end

function swatch(ov, xs, y, item, st)
% Colour sample: a filled square for bars, a line stub (with the series marker) for lines
    s = st.swatchIn;
    if strcmp(item.kind, 'bar')
        patch(ov, [xs, xs + s, xs + s, xs], [y - s/2, y - s/2, y + s/2, y + s/2], item.color, ...
            'EdgeColor', 'none');
    else
        plot(ov, [xs - 0.06, xs + s + 0.06], [y, y], '-', 'Color', item.color, 'LineWidth', st.lineWidth);
        if ~strcmp(item.kind, 'line')
            plot(ov, xs + s/2, y, 'LineStyle', 'none', 'Marker', item.kind, 'MarkerSize', st.markerSize - 1, ...
                'MarkerFaceColor', item.color, 'MarkerEdgeColor', 'w', 'LineWidth', 1.2);
        end
    end
end

function series(ax, x, y, col, mk, st)
% Line first, then markers with a thin white ring (drawn separately so the ring
% does not take the line's width)
    plot(ax, x, y, '-', 'Color', col, 'LineWidth', st.lineWidth);
    plot(ax, x, y, 'LineStyle', 'none', 'Marker', mk, 'MarkerSize', st.markerSize, ...
        'MarkerFaceColor', col, 'MarkerEdgeColor', 'w', 'LineWidth', 1.5);
end

function valueLabel(ax, x, y, str, st, where, gapIn)
% Value next to a point or bar top. The gap is measured in inches from the mark to the
% digits themselves (baseline or cap height), so it does not depend on the font's padding.
    if nargin < 6 || isempty(where), where = 'above'; end
    if nargin < 7, gapIn = st.barLabelGapIn; end
    ha = 'center';
    switch where
        case 'below'
            yy = yShift(ax, y, -gapIn);  va = 'cap';
        case 'aboveLeft'     % for a point whose line leaves steeply upward to the right
            yy = yShift(ax, y, gapIn);   va = 'baseline';  ha = 'right';
            pos = get(ax, 'Position');
            x   = x + 0.10 * diff(get(ax, 'XLim')) / pos(3);
        otherwise
            yy = yShift(ax, y, gapIn);   va = 'baseline';
    end
    text(x, yy, str, 'Parent', ax, 'HorizontalAlignment', ha, 'VerticalAlignment', va, ...
        'FontName', st.fontName, 'FontSize', st.valueFontSize, 'Color', st.colors.text, ...
        'Interpreter', 'none', 'Clipping', 'off');
end

function note(ax, x, y, str, st, varargin)
% Small muted annotation in data units; extra name/value pairs go to text()
    text(x, y, str, 'Parent', ax, 'FontName', st.fontName, 'FontSize', st.noteFontSize, ...
        'Color', st.colors.muted, 'Interpreter', 'none', 'Clipping', 'off', varargin{:});
end

function yy = yShift(ax, y, dIn)
% y moved up by dIn inches on this axes (set YLim and YScale before calling)
    pos = get(ax, 'Position');   % inches
    h   = pos(4);
    lim = get(ax, 'YLim');
    if strcmp(get(ax, 'YScale'), 'log')
        yy = y .* (lim(2) / lim(1)) .^ (dIn / h);
    else
        yy = y + dIn * diff(lim) / h;
    end
end

function fn = pickFont(want)
    if any(strcmpi(listfonts, want))
        fn = want;
    else
        fn = 'Helvetica';
        warning('posterKit:font', ...
            ['Font "%s" is not installed, so the charts use %s and will not match the poster text. ' ...
             'Install %s (all weights), restart MATLAB and run again.'], want, fn, want);
    end
end

function exportFig(fig, outDir, name, st)
% PNG at exactly the figure size x exportDpi. print keeps the full figure; exportgraphics
% would crop to the ink and change the size from chart to chart.
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    drawnow;
    file = fullfile(outDir, [name '.png']);
    print(fig, file, '-dpng', sprintf('-r%d', st.exportDpi));

    sz   = get(fig, 'UserData');
    sz   = sz.sizeIn;
    want = round(sz * st.exportDpi);
    info = imfinfo(file);
    fprintf('  wrote %s.png  %d x %d px  (%.2f x %.2f in at %d dpi; %d x %d px on the poster)\n', ...
        name, info.Width, info.Height, sz(1), sz(2), st.exportDpi, ...
        round(sz(1) * st.pxPerIn), round(sz(2) * st.pxPerIn));
    if any(abs([info.Width, info.Height] - want) > 2)
        warning('posterKit:exportSize', '%s.png is %d x %d px, expected %d x %d px.', ...
            name, info.Width, info.Height, want(1), want(2));
    end
end
