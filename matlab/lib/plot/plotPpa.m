function plotPpa(T, cfg, outDir)
% plotPpa  Draw the poster's result charts (Figs. 6 to 10) from the PPA table.
%
%   plotPpa(T, cfg, outDir)
%
%   AI note: written by Claude (Anthropic) for Ryan Hall's FIR_Filter project.
%
%   T       table from buildPpaTable (one row per platform and LANES value)
%   cfg     config(); colours, fonts, sizes and the 96 kHz requirement come from cfg.ppa
%   outDir  folder for the exports: each figure is saved as a vector PDF (for the poster)
%           and a 300 dpi PNG (for previews)
%
%   Every figure has a title that states its finding and a caption that says what is
%   plotted. Figures are drawn at their final print size (cfg.ppa.figSize, inches), so
%   font sizes are real point sizes on the poster. FPGA is teal and ASIC copper; the
%   x axis is always the number of lanes, evenly spaced.
%
%     fig06_area_vs_lanes    FPGA LUTs and ASIC cell area, two panels in absolute units
%     fig07_speed_vs_lanes   max sample rate, with the 96 kHz requirement
%     fig08_energy_vs_lanes  energy per sample (FPGA dynamic, ASIC total)
%     fig09_power_25mhz      power at 25 MHz: FPGA static + dynamic vs ASIC total
%     fig10_asic_area_split  ASIC cell area by cell type, and the lane count that did not route

    p  = cfg.ppa;
    c  = p.colors;
    fn = pickFont(p.font);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    F = sortrows(T(T.platform == "FPGA", :), 'lanes');
    A = sortrows(T(T.platform == "ASIC", :), 'lanes');
    lanes = p.lanes(:);
    pos   = @(L) arrayfun(@(v) find(lanes == v), L);   % evenly spaced x position of a lane count
    xLab  = 'Number of lanes';
    keyF  = 'FPGA (Artix-7)';
    keyA  = 'ASIC (Sky130)';
    refMHz = 1e3 / p.refPeriodNs;

    % ---------------- Fig. 6: area vs lanes (two panels, absolute units) ----------------
    [fig, reg] = newCanvas(p.figSize.area, p, fn, ...
        'Area grows alike up to 4 lanes; at 8 the FPGA''s sample buffer leaves block RAM', ...
        sprintf(['FPGA: LUTs used on the Artix-7 (DSP build). ASIC: Sky130 standard-cell area. ' ...
                 'Both at a %g ns (%g MHz) clock. From 8 lanes Vivado builds the 117-sample ' ...
                 'buffer from LUTs instead of block RAM.'], p.refPeriodNs, refMHz));
    ax1 = newAxes(fig, [reg(1), reg(2), reg(3) / 2, reg(4)], p, fn);
    plotSeries(ax1, pos(F.lanes), F.area, c.fpga, 'o', @(v) commaInt(v), p, fn);
    lanesAxis(ax1, lanes, xLab);
    ax1.YLim = [0, niceTop(max(F.area))];
    ax1.YAxis.Exponent = 0;
    ax1.YTickLabel = arrayfun(@commaInt, ax1.YTick, 'UniformOutput', false);
    ylabel(ax1, 'LUTs');
    panelTitle(ax1, keyF, c.fpga, p, fn);
    ax2 = newAxes(fig, [reg(1) + reg(3) / 2, reg(2), reg(3) / 2, reg(4)], p, fn);
    plotSeries(ax2, pos(A.lanes), A.area / 1e6, c.asic, 's', @(v) sprintf('%.2f', v), p, fn);
    lanesAxis(ax2, lanes, xLab);
    ax2.YLim = [0, niceTop(max(A.area / 1e6))];
    ylabel(ax2, 'Cell area (mm^2)');
    panelTitle(ax2, keyA, c.asic, p, fn);
    exportFig(fig, outDir, 'fig06_area_vs_lanes');

    % ---------------- Fig. 7: max sample rate vs lanes ----------------
    shared = intersect(F.lanes, A.lanes);
    ratio  = F.maxRateMsps(ismember(F.lanes, shared)) ./ A.maxRateMsps(ismember(A.lanes, shared));
    [fig, reg] = newCanvas(p.figSize.speed, p, fn, ...
        sprintf('The FPGA is %.0f to %.0f times faster; both clear %g kHz with room to spare', ...
                round(min(ratio)), round(max(ratio)), p.requiredMsps * 1e3), ...
        ['Max sample rate = Fmax / clocks per sample, with clocks per sample measured in ' ...
         'simulation (64, 35, 20, 13, 9). FPGA Fmax from the fastest clock that met timing; ' ...
         sprintf('ASIC Fmax from the %g ns run.', p.refPeriodNs)]);
    ax = newAxes(fig, reg, p, fn);
    hF = plotSeries(ax, pos(F.lanes), F.maxRateMsps, c.fpga, 'o', @(v) sprintf('%.1f', v), p, fn);
    hA = plotSeries(ax, pos(A.lanes), A.maxRateMsps, c.asic, 's', @(v) sprintf('%.2g', v), p, fn);
    lanesAxis(ax, lanes, xLab);
    ax.YLim = [0, niceTop(max(F.maxRateMsps))];
    ylabel(ax, 'Max sample rate (MS/s)');
    yline(ax, p.requiredMsps, '--', sprintf('%g kHz requirement', p.requiredMsps * 1e3), ...
        'Color', c.muted, 'LineWidth', 1.5, 'FontName', fn, 'FontSize', p.keyFontSize, ...
        'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', 'top');
    smallKey(ax, [hF, hA], {keyF, keyA}, 'northeast', p, fn);
    exportFig(fig, outDir, 'fig07_speed_vs_lanes');

    % ---------------- Fig. 8: energy per sample vs lanes ----------------
    [fig, reg] = newCanvas(p.figSize.energy, p, fn, ...
        {'More lanes cut energy per sample', 'on the ASIC, but not on the FPGA'}, ...
        ['Energy per sample = power x clock period x clocks per sample. FPGA: dynamic power ' ...
         'only. ASIC: total power. Both are tool estimates with default switching activity.']);
    ax = newAxes(fig, reg, p, fn);
    hF = plotSeries(ax, pos(F.lanes), F.energyPerSample_nJ, c.fpga, 'o', @(v) sprintf('%.1f', v), p, fn);
    hA = plotSeries(ax, pos(A.lanes), A.energyPerSample_nJ, c.asic, 's', @(v) sprintf('%.1f', v), p, fn);
    lanesAxis(ax, lanes, xLab);
    ax.YLim = [0, niceTop(max([F.energyPerSample_nJ; A.energyPerSample_nJ]))];
    ylabel(ax, 'Energy per sample (nJ)');
    smallKey(ax, [hF, hA], {keyF, keyA}, 'north', p, fn);
    exportFig(fig, outDir, 'fig08_energy_vs_lanes');

    % ---------------- Fig. 9: power at 25 MHz ----------------
    Fs = F(ismember(F.lanes, shared), :);
    As = A(ismember(A.lanes, shared), :);
    x  = pos(shared);
    [fig, reg] = newCanvas(p.figSize.power, p, fn, ...
        {sprintf('At %g MHz the FPGA draws about %.0fx', refMHz, Fs.power_mW(1) / As.power_mW(1)), ...
         'the ASIC''s power, almost all of it static'}, ...
        sprintf(['Total power at a %g ns (%g MHz) clock. FPGA static power is the whole ' ...
                 'Artix-7''s leakage, paid whether or not the filter is busy.'], p.refPeriodNs, refMHz));
    ax = newAxes(fig, reg, p, fn);
    bF = bar(ax, x - 0.2, [Fs.static_mW, Fs.dynamic_mW], 0.35, 'stacked', 'EdgeColor', 'none');
    bF(1).FaceColor = mix(c.fpga, 0.55);
    bF(2).FaceColor = c.fpga;
    bA = bar(ax, x + 0.2, As.power_mW, 0.35, 'FaceColor', c.asic, 'EdgeColor', 'none');
    for i = 1:numel(x)
        valueLabel(ax, x(i) - 0.2, Fs.power_mW(i), sprintf('%.0f', Fs.power_mW(i)), p, fn);
        valueLabel(ax, x(i) + 0.2, As.power_mW(i), sprintf('%.0f', As.power_mW(i)), p, fn);
    end
    lanesAxis(ax, lanes(1:max(x)), xLab);
    ax.YLim = [0, niceTop(max(Fs.power_mW))];
    ylabel(ax, 'Power (mW)');
    smallKey(ax, [bF(1), bF(2), bA], {'FPGA static', 'FPGA dynamic', 'ASIC'}, 'eastoutside', p, fn);
    exportFig(fig, outDir, 'fig09_power_25mhz');

    % ---------------- Fig. 10: ASIC area by cell type, and where it stops routing ----------------
    M  = [A.comb_um2, A.seq_um2, A.repair_um2, A.clock_um2, A.tap_um2] / 1e6;   % mm^2
    xa = pos(A.lanes);
    failX = p.asicFailedLanes(:);
    [fig, reg] = newCanvas(p.figSize.areaSplit, p, fn, ...
        {'Logic, not flip-flops, grows with lanes,', sprintf('until %d lanes cannot be routed', failX(1))}, ...
        sprintf(['Sky130 cell area at %g ns by cell type. Logic is mostly the sample buffer''s read ' ...
                 'multiplexers and the lane multipliers. %d lanes failed global routing at 25%% ' ...
                 'core utilization.'], p.refPeriodNs, failX(1)));
    ax = newAxes(fig, reg, p, fn);
    b = bar(ax, xa, M, 0.6, 'stacked', 'EdgeColor', 'none');
    b(1).FaceColor = c.asic;            % logic: multiplexers, multipliers, adders
    b(2).FaceColor = c.navy;            % flip-flops (mostly the sample buffer)
    b(3).FaceColor = mix(c.asic, 0.5);  % timing-repair buffers
    b(4).FaceColor = c.muted;           % clock tree
    b(5).FaceColor = c.grid;            % tap cells
    tot = sum(M, 2);
    for i = 1:numel(xa)
        valueLabel(ax, xa(i), tot(i), sprintf('%.2f', tot(i)), p, fn);
    end
    top = niceTop(max(tot));
    for j = 1:numel(failX)
        text(ax, pos(failX(j)), 0.25 * top, {'did not', 'route'}, 'Color', c.asic, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', 'FontName', fn, 'FontSize', p.fontSize);
    end
    lanesAxis(ax, lanes(1:max([xa; pos(failX)])), xLab);
    ax.YLim = [0, top];
    ylabel(ax, 'Cell area (mm^2)');
    smallKey(ax, flip(b), flip({'Logic', 'Flip-flops', 'Timing buffers', 'Clock tree', 'Tap cells'}), ...
        'eastoutside', p, fn);
    exportFig(fig, outDir, 'fig10_asic_area_split');
end

% -------------------------------------------------------------------------
function [fig, region] = newCanvas(sz, p, fn, titleText, caption)
% A figure at print size with a title band on top and a caption band at the bottom;
% region = normalized [x y w h] left for the axes.
    c   = p.colors;
    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 sz]);
    tFrac = p.titleIn   / sz(2);
    cFrac = p.captionIn / sz(2);
    annotation(fig, 'textbox', [0.01, 1 - tFrac, 0.98, tFrac], 'String', titleText, ...
        'EdgeColor', 'none', 'FontName', fn, 'FontSize', p.titleFontSize, 'FontWeight', 'bold', ...
        'Color', c.text, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'Interpreter', 'none');
    annotation(fig, 'textbox', [0.01, 0, 0.98, cFrac], 'String', caption, ...
        'EdgeColor', 'none', 'FontName', fn, 'FontSize', p.captionFontSize, 'Color', c.muted, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'Interpreter', 'none');
    region = [0, cFrac, 1, 1 - cFrac - tFrac];
end

function ax = newAxes(fig, outerPos, p, fn)
    c  = p.colors;
    ax = axes(fig, 'OuterPosition', outerPos);
    hold(ax, 'on');
    box(ax, 'off');
    set(ax, 'FontName', fn, 'FontSize', p.fontSize, 'LineWidth', 1.25, 'TickDir', 'out', ...
        'XColor', c.muted, 'YColor', c.muted, 'GridColor', c.grid, 'GridAlpha', 1, ...
        'YGrid', 'on', 'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1);
    ax.XLabel.Color = c.text;
    ax.YLabel.Color = c.text;
end

function h = plotSeries(ax, x, y, col, mk, fmt, p, fn)
    h = plot(ax, x, y, ['-' mk], 'Color', col, 'LineWidth', 3, 'MarkerSize', 11, ...
        'MarkerFaceColor', col, 'MarkerEdgeColor', 'w');
    for i = 1:numel(x)
        valueLabel(ax, x(i), y(i), fmt(y(i)), p, fn);
    end
end

function valueLabel(ax, x, y, str, p, fn)
% Small value label just above a point or bar
    text(ax, x, y, str, 'Color', p.colors.text, 'FontName', fn, 'FontSize', p.keyFontSize, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Margin', 6);
end

function lanesAxis(ax, lanes, xLab)
% Lane counts at evenly spaced positions 1..n
    n = numel(lanes);
    set(ax, 'XTick', 1:n, 'XTickLabel', compose('%d', lanes(:)), 'XLim', [0.5, n + 0.5], ...
        'XMinorTick', 'off', 'YMinorTick', 'off');
    xlabel(ax, xLab);
end

function panelTitle(ax, str, col, p, fn)
    title(ax, str, 'Color', col, 'FontName', fn, 'FontSize', p.fontSize, 'FontWeight', 'bold');
end

function smallKey(ax, h, names, where, p, fn)
    legend(ax, h, names, 'Location', where, 'Box', 'off', 'FontName', fn, ...
        'FontSize', p.keyFontSize, 'TextColor', p.colors.muted, 'AutoUpdate', 'off');
end

function t = niceTop(v)
% Axis top with ~20% headroom for value labels, rounded to 1, 2 or 5 x 10^k
    v = 1.2 * v;
    k = 10 ^ floor(log10(v));
    steps = [1 2 2.5 5 10] * k;
    t = steps(find(steps >= v, 1));
end

function s = commaInt(v)
    s = regexprep(sprintf('%d', round(v)), '(\d)(?=(\d{3})+$)', '$1,');
end

function col = mix(col, w)
% Blend a colour toward white by fraction w (0 = unchanged, 1 = white)
    col = col + (1 - col) * w;
end

function fn = pickFont(want)
    if any(strcmpi(listfonts, want))
        fn = want;
    else
        fn = 'Helvetica';
        warning('plotPpa:font', 'Font "%s" not installed; using %s. Install IBM Plex Sans for the poster.', want, fn);
    end
end

function exportFig(fig, outDir, name)
    exportgraphics(fig, fullfile(outDir, [name '.pdf']), 'ContentType', 'vector', 'BackgroundColor', 'white');
    exportgraphics(fig, fullfile(outDir, [name '.png']), 'Resolution', 300, 'BackgroundColor', 'white');
    fprintf('  wrote %s (.pdf, .png)\n', name);
end
