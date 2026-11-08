function plotPpa(T, cfg, outDir)
% plotPpa  Draw the poster's result charts (Figs. 6 to 10) from the PPA table.
%
%   plotPpa(T, cfg, outDir)
%
%   AI note: written by Claude (Anthropic) for Ryan Hall's FIR_Filter project.
%
%   T       table from buildPpaTable (one row per platform and LANES value)
%   cfg     config(); colours, font, sizes and the 96 kHz requirement come from cfg.ppa
%   outDir  folder for the exports: each figure is saved as a vector PDF (for the poster)
%           and a 300 dpi PNG (for previews)
%
%   Figures are drawn at their final print size (cfg.ppa.figSize, inches) so the font sizes
%   are the real point sizes on the poster. FPGA is always teal and ASIC always copper.
%   Chart titles are left off: the poster panel heading carries each chart's finding.
%
%     fig06_area_vs_lanes    area relative to 1 lane, log scale, both platforms
%     fig07_speed_vs_lanes   max sample rate, log scale, with the 96 kHz requirement
%     fig08_energy_vs_lanes  energy per sample (FPGA dynamic, ASIC total)
%     fig09_power_25mhz      power at 25 MHz: FPGA static + dynamic vs ASIC total
%     fig10_asic_area_split  ASIC cell area by kind, and the lane count that did not route

    p  = cfg.ppa;
    c  = p.colors;
    fn = pickFont(p.font);
    tx = {'FontName', fn, 'FontSize', p.fontSize};    % for text() calls
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    F = sortrows(T(T.platform == "FPGA", :), 'lanes');
    A = sortrows(T(T.platform == "ASIC", :), 'lanes');
    lw = 3;  ms = 11;
    plotLine = @(ax, R, y, col, mk) plot(ax, R.lanes, y, ['-' mk], 'Color', col, 'LineWidth', lw, ...
        'MarkerSize', ms, 'MarkerFaceColor', col, 'MarkerEdgeColor', 'w');
    failX = p.asicFailedLanes;

    % ---------------- Fig. 6: area vs lanes ----------------
    [fig, ax] = newFig(p.figSize.area, p, fn);
    plotLine(ax, F, F.areaRel, c.fpga, 'o');
    plotLine(ax, A, A.areaRel, c.asic, 's');
    lanesAxis(ax, p.lanes);
    set(ax, 'YScale', 'log', 'YLim', [0.4 300], 'YTick', [1 2 5 10 20 50 100 200], ...
        'YTickLabel', {'1x', '2x', '5x', '10x', '20x', '50x', '100x', '200x'});
    ylabel(ax, 'Area vs 1 lane');
    % Label positions are hand-placed in clear space; adjust here if the data change
    text(ax, F.lanes(end) * 1.1, F.areaRel(end) / 2.2, 'FPGA (LUTs)', 'Color', c.fpga, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'right', tx{:});
    text(ax, 1, 0.6, 'ASIC (cell area)', 'Color', c.asic, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'left', tx{:});
    k8 = F.lanes == 8;
    if any(k8)
        text(ax, 7.4, F.areaRel(k8) * 1.5, 'buffer leaves block RAM', 'Color', c.text, ...
            'HorizontalAlignment', 'right', tx{:});
    end
    for x = failX
        text(ax, x, 1.0, {'ASIC: did', 'not route'}, 'Color', c.asic, 'HorizontalAlignment', 'center', tx{:});
    end
    exportFig(fig, outDir, 'fig06_area_vs_lanes');

    % ---------------- Fig. 7: max sample rate vs lanes ----------------
    [fig, ax] = newFig(p.figSize.speed, p, fn);
    plotLine(ax, F, F.maxRateMsps, c.fpga, 'o');
    plotLine(ax, A, A.maxRateMsps, c.asic, 's');
    lanesAxis(ax, p.lanes);
    set(ax, 'YScale', 'log', 'YLim', [0.05 20], 'YTick', [0.1 0.3 1 3 10], ...
        'YTickLabel', {'0.1', '0.3', '1', '3', '10'});
    ylabel(ax, 'Max sample rate (MS/s)');
    yline(ax, p.requiredMsps, '--', sprintf('%g kHz requirement', p.requiredMsps * 1e3), ...
        'Color', c.muted, 'LineWidth', 2, 'FontName', fn, 'FontSize', p.fontSize, ...
        'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', 'top');
    text(ax, F.lanes(2), F.maxRateMsps(2) * 1.9, 'FPGA', 'Color', c.fpga, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', tx{:});
    text(ax, A.lanes(end) * 1.12, A.maxRateMsps(end), 'ASIC', 'Color', c.asic, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', tx{:});
    exportFig(fig, outDir, 'fig07_speed_vs_lanes');

    % ---------------- Fig. 8: energy per sample vs lanes ----------------
    [fig, ax] = newFig(p.figSize.energy, p, fn);
    plotLine(ax, F, F.energyPerSample_nJ, c.fpga, 'o');
    plotLine(ax, A, A.energyPerSample_nJ, c.asic, 's');
    lanesAxis(ax, p.lanes);
    yMax = 5 * ceil(max([F.energyPerSample_nJ; A.energyPerSample_nJ]) / 5 + 0.2);
    set(ax, 'YLim', [0 yMax]);
    ylabel(ax, 'nJ per sample');
    pct = (A.energyPerSample_nJ(end) / A.energyPerSample_nJ(1) - 1) * 100;
    text(ax, A.lanes(1), A.energyPerSample_nJ(1) + 0.17 * yMax, sprintf('ASIC %+.0f%%', pct), ...
        'Color', c.asic, 'FontWeight', 'bold', 'HorizontalAlignment', 'left', tx{:});
    text(ax, F.lanes(1), F.energyPerSample_nJ(1) + 0.12 * yMax, 'FPGA (dynamic)', 'Color', c.fpga, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'left', tx{:});
    exportFig(fig, outDir, 'fig08_energy_vs_lanes');

    % ---------------- Fig. 9: power at 25 MHz ----------------
    shared = intersect(F.lanes, A.lanes);
    Fs = F(ismember(F.lanes, shared), :);
    As = A(ismember(A.lanes, shared), :);
    x  = (1:numel(shared))';
    [fig, ax] = newFig(p.figSize.power, p, fn);
    ax.YGrid = 'on';
    bF = bar(ax, x - 0.2, [Fs.static_mW, Fs.dynamic_mW], 0.35, 'stacked', 'EdgeColor', 'none');
    bF(1).FaceColor = mix(c.fpga, 0.55);
    bF(2).FaceColor = c.fpga;
    bA = bar(ax, x + 0.2, As.power_mW, 0.35, 'FaceColor', c.asic, 'EdgeColor', 'none');
    yTop = 10 * ceil(max(Fs.power_mW) * 1.25 / 10);
    set(ax, 'XTick', x, 'XTickLabel', compose('%d', shared), 'XLim', [0.4, numel(shared) + 0.6], ...
        'YLim', [0 yTop]);
    xlabel(ax, 'Parallel lanes');
    ylabel(ax, 'mW at 25 MHz');
    for i = 1:numel(x)
        text(ax, x(i) - 0.2, Fs.power_mW(i), sprintf('%.0f', Fs.power_mW(i)), 'Color', c.text, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', tx{:});
        text(ax, x(i) + 0.2, As.power_mW(i), sprintf('%.0f', As.power_mW(i)), 'Color', c.text, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', tx{:});
    end
    legend(ax, [bF(1), bF(2), bA], {'FPGA static', 'FPGA dynamic', 'ASIC total'}, ...
        'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', ...
        'FontName', fn, 'FontSize', p.fontSize, 'TextColor', c.text);
    exportFig(fig, outDir, 'fig09_power_25mhz');

    % ---------------- Fig. 10: ASIC area split, and where it stops routing ----------------
    M = [A.comb_um2, A.seq_um2, A.repair_um2, A.clock_um2, A.tap_um2] / 1e3;
    nA = height(A);
    xs = (1:nA)';
    [fig, ax] = newFig(p.figSize.areaSplit, p, fn);
    ax.YGrid = 'on';
    b = bar(ax, xs, M, 0.6, 'stacked', 'EdgeColor', 'none');
    b(1).FaceColor = c.asic;           % logic: multiplexers, multipliers, adders
    b(2).FaceColor = c.navy;           % flip-flops (sample buffer is most of them)
    b(3).FaceColor = mix(c.asic, 0.5); % timing-repair buffers
    b(4).FaceColor = c.muted;          % clock tree
    b(5).FaceColor = c.grid;           % tap cells
    labels = compose('%d', A.lanes);
    xlimR = nA + 0.6;
    if ~isempty(failX)
        labels = [labels; compose('%d', failX(:))];
        xlimR  = nA + numel(failX) + 0.6;
        for j = 1:numel(failX)
            text(ax, nA + j, 0.3 * max(sum(M, 2)), {'did not', 'route'}, 'Color', c.asic, ...
                'FontWeight', 'bold', 'HorizontalAlignment', 'center', tx{:});
        end
    end
    set(ax, 'XTick', 1:numel(labels), 'XTickLabel', labels, 'XLim', [0.4 xlimR], ...
        'YLim', [0, 100 * ceil(max(sum(M, 2)) * 1.1 / 100)]);
    xlabel(ax, 'Parallel lanes');
    ylabel(ax, '10^3 \mum^2');
    legend(ax, flip(b), flip({'Logic', 'Flip-flops', 'Timing buffers', 'Clock tree', 'Tap cells'}), ...
        'Location', 'eastoutside', 'Box', 'off', 'FontName', fn, 'FontSize', p.fontSize, 'TextColor', c.text);
    exportFig(fig, outDir, 'fig10_asic_area_split');
end

% -------------------------------------------------------------------------
function [fig, ax] = newFig(sz, p, fn)
    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 sz]);
    ax  = axes(fig);
    hold(ax, 'on');
    box(ax, 'off');
    set(ax, 'FontName', fn, 'FontSize', p.fontSize, 'LineWidth', 1.25, 'TickDir', 'out', ...
        'XColor', p.colors.muted, 'YColor', p.colors.muted, 'GridColor', p.colors.grid, ...
        'GridAlpha', 1, 'YGrid', 'on', 'LabelFontSizeMultiplier', 1);
    ax.XLabel.Color = p.colors.text;
    ax.YLabel.Color = p.colors.text;
end

function lanesAxis(ax, lanes)
    set(ax, 'XScale', 'log', 'XTick', lanes, 'XTickLabel', compose('%d', lanes), ...
        'XLim', [lanes(1) / 1.3, lanes(end) * 1.3], 'XMinorTick', 'off', 'YMinorTick', 'off');
    xlabel(ax, 'Parallel lanes (LANES)');
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
