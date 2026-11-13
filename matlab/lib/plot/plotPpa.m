function plotPpa(T, cfg, outDir)
% plotPpa  Draw the poster's four result charts (Figs. 6 to 9) from the PPA table.
%
%   plotPpa(T, cfg, outDir)
%
%   AI note: written by Claude (Anthropic) for Ryan Hall's FIR_Filter project.
%
%   T       table from buildPpaTable (one row per platform and LANES value)
%   cfg     config(); data settings in cfg.ppa, the shared chart look in cfg.poster
%   outDir  folder for the PNGs
%
%   Each chart is drawn at the exact size of its slot on the poster (cfg.poster.figSize.result)
%   and exported as a PNG that drops straight into the card. The charts have no title and no
%   caption, because the poster card already carries both. All four share one pattern
%   (lib/plot/posterKit.m):
%     * header row: what the y axis measures (left) and the colour key (right)
%     * x axis: number of lanes, evenly spaced, always the full set in cfg.ppa.lanes
%     * FPGA teal, ASIC copper; values printed at the marks; text in ink, never in a series colour
%     * ASIC lane counts in cfg.ppa.asicFailedLanes are marked "did not route"
%
%     fig06_area     left: FPGA LUTs; right: ASIC cell area stacked by cell type
%     fig07_speed    max sample rate (log axis) with the sample-rate requirement
%     fig08_energy   energy per sample (FPGA dynamic power, ASIC total power)
%     fig09_power    power at the reference clock: FPGA static + dynamic beside ASIC total

    p   = cfg.ppa;
    kit = posterKit(cfg);
    st  = kit.st;
    c   = st.colors;
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    F = sortrows(T(T.platform == "FPGA", :), 'lanes');
    A = sortrows(T(T.platform == "ASIC", :), 'lanes');
    lanes = p.lanes(:);
    n     = numel(lanes);
    pos   = @(L) arrayfun(@(v) find(lanes == v), L);     % evenly spaced x position of a lane count
    xF    = pos(F.lanes);
    xA    = pos(A.lanes);
    failLanes = intersect(p.asicFailedLanes(:), lanes);  % ASIC lane counts that did not route
    failX     = pos(failLanes);

    % Geometry shared by all four charts (inches)
    sz    = st.figSize.result;
    W     = sz(1);
    H     = sz(2);
    ph    = H - st.botIn - st.headIn;                                  % plot height
    yHead = st.botIn + ph + 0.22;                                      % centre line of the header row
    full  = [st.leftIn, st.botIn, W - st.leftIn - st.rightIn, ph];     % plot area of a one-panel chart
    keyF  = keyItem(c.fpga, 'FPGA', 'o');
    keyA  = keyItem(c.asic, 'ASIC', 's');
    centred = {'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom'};

    % ---------------- Fig. 6: area (two panels, each in its own unit) ----------------
    gap = 0.66;                                            % between the panels: the right panel's axis numbers
    w1  = 0.49 * (W - st.leftIn - gap - st.rightIn);
    l2  = st.leftIn + w1 + gap;
    w2  = W - l2 - st.rightIn;
    fig = kit.newFigure('Fig. 6 area', sz);

    % Left: FPGA LUTs. Extra headroom for the block-RAM bracket.
    ax1 = kit.newAxes(fig, [st.leftIn, st.botIn, w1, ph]);
    [top, ticks, labels] = linearScale(max(F.area), ph, 0.50);
    kit.yAxis(ax1, [0, top], ticks, labels);
    bar(ax1, xF, F.area, st.barWidth, 'FaceColor', c.fpga, 'EdgeColor', 'none', 'ShowBaseLine', 'off');
    kit.lanesAxis(ax1, lanes);
    for i = 1:numel(xF)
        kit.valueLabel(ax1, xF(i), F.area(i), commaInt(F.area(i)));
    end
    inRam = xF(F.bram > 0);                                % lane counts whose sample buffer is still in block RAM
    if ~isempty(inRam) && numel(inRam) < numel(xF)
        x0 = min(inRam) - 0.30;
        x1 = max(inRam) + 0.30;
        yb = kit.yShift(ax1, top, -0.60);
        yt = kit.yShift(ax1, top, -0.67);
        plot(ax1, [x0, x0, x1, x1], [yt, yb, yb, yt], '-', 'Color', c.muted, 'LineWidth', 1);
        kit.note(ax1, (x0 + x1) / 2, kit.yShift(ax1, top, -0.54), {'buffer in', 'block RAM'}, centred{:});
    end

    % Right: ASIC cell area by cell type. "Buffers" is everything that is not logic or a
    % flip-flop (timing-repair buffers, clock tree, tap cells, antenna diodes), so the stack
    % adds up to the reported cell area.
    ax2  = kit.newAxes(fig, [l2, st.botIn, w2, ph]);
    seq  = A.seq_um2  / 1e6;                               % mm^2
    comb = A.comb_um2 / 1e6;
    tot  = A.area     / 1e6;
    rest = tot - seq - comb;
    [top, ticks, labels] = linearScale(max(tot), ph, st.labelRoomIn);
    kit.yAxis(ax2, [0, top], ticks, labels);
    b = bar(ax2, xA, [seq, comb, rest], st.barWidth, 'stacked', 'EdgeColor', 'none', 'ShowBaseLine', 'off');
    set(b(1), 'FaceColor', c.navy);         % flip-flops (mostly the sample buffer): at the bottom, where "flat" is easy to see
    set(b(2), 'FaceColor', c.asic);         % logic: read multiplexers, multipliers, adders
    set(b(3), 'FaceColor', c.asicLight);    % buffers and the rest
    segmentGaps(ax2, xA, [seq, seq + comb], st.barWidth);
    kit.lanesAxis(ax2, lanes);
    for i = 1:numel(xA)
        kit.valueLabel(ax2, xA(i), tot(i), sprintf('%.2f', tot(i)));
    end
    for j = 1:numel(failX)
        kit.note(ax2, failX(j), kit.yShift(ax2, 0, 0.07), {'did not', 'route'}, centred{:});
    end

    ov = kit.overlay(fig);
    kit.header(ov, st.headerXIn, yHead, 'FPGA', 'LUTs used');
    kit.header(ov, l2 - 0.47, yHead, 'ASIC', ['cell area (mm' char(178) ')']);
    kit.keyColumn(ov, l2 + w2, st.botIn + ph - 0.13, ...
        [keyItem(c.asicLight, 'Buffers', 'bar'), keyItem(c.asic, 'Logic', 'bar'), keyItem(c.navy, 'Flip-flops', 'bar')]);
    kit.export(fig, outDir, 'fig06_area');

    % ---------------- Fig. 7: max sample rate (log axis: equal ratios are equal distances) ----------------
    req = p.requiredMsps;
    lo  = req / 2;
    hi  = 3 * max([F.maxRateMsps; A.maxRateMsps]);
    dec = 10 .^ (ceil(log10(lo)):floor(log10(hi)));
    fig = kit.newFigure('Fig. 7 speed', sz);
    ax  = kit.newAxes(fig, full);
    set(ax, 'YScale', 'log');
    kit.yAxis(ax, [lo, hi], dec, compose('%g', dec(:)));
    set(ax, 'YMinorTick', 'off', 'YMinorGrid', 'off');
    plot(ax, [0.5, n + 0.5], [req, req], '--', 'Color', c.navy, 'LineWidth', 1.5);
    kit.series(ax, xF, F.maxRateMsps, c.fpga, 'o');
    kit.series(ax, xA, A.maxRateMsps, c.asic, 's');
    kit.lanesAxis(ax, lanes);
    whereF = 'above';
    whereA = 'below';
    if mean(A.maxRateMsps) > mean(F.maxRateMsps)
        whereF = 'below';
        whereA = 'above';
    end
    labelSeries(kit, ax, xF, F.maxRateMsps, @rateStr, whereF);
    labelSeries(kit, ax, xA, A.maxRateMsps, @rateStr, whereA);
    kit.note(ax, n + 0.45, kit.yShift(ax, req, 0.06), sprintf('%g kHz required', req * 1e3), ...
        'Color', c.navy, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'baseline');
    asicEndNote(kit, ax, n, A.maxRateMsps, failLanes);
    ov = kit.overlay(fig);
    kit.header(ov, st.headerXIn, yHead, '', 'Max sample rate (MS/s, log scale)');
    kit.keyRow(ov, W - st.rightIn, yHead, [keyF, keyA]);
    kit.export(fig, outDir, 'fig07_speed');

    % ---------------- Fig. 8: energy per sample ----------------
    fig = kit.newFigure('Fig. 8 energy', sz);
    ax  = kit.newAxes(fig, full);
    [top, ticks, labels] = linearScale(max([F.energyPerSample_nJ; A.energyPerSample_nJ]), ph, st.labelRoomIn);
    kit.yAxis(ax, [0, top], ticks, labels);
    kit.series(ax, xF, F.energyPerSample_nJ, c.fpga, 'o');
    kit.series(ax, xA, A.energyPerSample_nJ, c.asic, 's');
    kit.lanesAxis(ax, lanes);
    labelSeries(kit, ax, xF, F.energyPerSample_nJ, @(v) sprintf('%.1f', v), 'above');
    labelSeries(kit, ax, xA, A.energyPerSample_nJ, @(v) sprintf('%.1f', v), 'above');
    asicEndNote(kit, ax, n, A.energyPerSample_nJ, failLanes);
    ov = kit.overlay(fig);
    kit.header(ov, st.headerXIn, yHead, '', 'Energy per sample (nJ)');
    kit.keyRow(ov, W - st.rightIn, yHead, [keyF, keyA]);
    kit.export(fig, outDir, 'fig08_energy');

    % ---------------- Fig. 9: power at the reference clock ----------------
    % Vivado reports static, dynamic and total power each rounded to 1 mW, so static + dynamic
    % can be 1 mW short of the total. The dynamic segment is drawn as total - static so every
    % bar reaches the total printed above it.
    bw  = st.pairBarWidth;
    off = st.pairOffset;
    fig = kit.newFigure('Fig. 9 power', sz);
    ax  = kit.newAxes(fig, full);
    [top, ticks, labels] = linearScale(max([F.power_mW; A.power_mW]), ph, st.labelRoomIn);
    kit.yAxis(ax, [0, top], ticks, labels);
    bF = bar(ax, xF - off, [F.static_mW, F.power_mW - F.static_mW], bw, 'stacked', ...
        'EdgeColor', 'none', 'ShowBaseLine', 'off');
    set(bF(1), 'FaceColor', c.fpgaLight);
    set(bF(2), 'FaceColor', c.fpga);
    segmentGaps(ax, xF - off, F.static_mW, bw);
    bar(ax, xA + off, A.power_mW, bw, 'FaceColor', c.asic, 'EdgeColor', 'none', 'ShowBaseLine', 'off');
    kit.lanesAxis(ax, lanes);
    for i = 1:numel(xF)
        kit.valueLabel(ax, xF(i) - off, F.power_mW(i), sprintf('%.0f', F.power_mW(i)));
    end
    for i = 1:numel(xA)
        kit.valueLabel(ax, xA(i) + off, A.power_mW(i), sprintf('%.0f', A.power_mW(i)));
    end
    for j = 1:numel(failX)
        kit.note(ax, failX(j) + 0.30, kit.yShift(ax, 0, 0.07), {'did not', 'route'}, centred{:});
    end
    ov = kit.overlay(fig);
    kit.header(ov, st.headerXIn, yHead, '', 'Power (mW)');
    kit.keyRow(ov, W - st.rightIn, yHead, ...
        [keyItem(c.fpgaLight, 'FPGA static', 'bar'), keyItem(c.fpga, 'FPGA dynamic', 'bar'), keyItem(c.asic, 'ASIC', 'bar')]);
    kit.export(fig, outDir, 'fig09_power');
end

% -------------------------------------------------------------------------
function s = keyItem(col, label, kind)
    s = struct('color', col, 'label', label, 'kind', kind);
end

function [top, ticks, labels] = linearScale(vmax, plotIn, roomIn)
% Zero-based axis: top leaves roomIn inches above the largest value for its printed number;
% at most three ticks above zero, on a 1-2-5 step. Thousands are written as 10k, 20k.
    top  = vmax / (1 - roomIn / plotIn);
    k    = 10 ^ floor(log10(top));
    cand = [0.1, 0.2, 0.5, 1, 2, 5, 10] * k;
    step = cand(find(floor(top ./ cand + 1e-9) <= 3, 1));
    ticks = 0:step:top;
    if step >= 1000
        labels = compose('%gk', ticks(:) / 1000);
    else
        labels = compose('%g', ticks(:));
    end
    labels{1} = '0';
end

function labelSeries(kit, ax, x, y, fmt, where)
% Print every value of a line series. A value whose line leaves steeply upward to the
% right is moved to the left of its marker so the line does not run through the digits.
    pos = get(ax, 'Position');   % inches
    xl  = get(ax, 'XLim');
    yl  = get(ax, 'YLim');
    xin = (x - xl(1)) / diff(xl) * pos(3);
    if strcmp(get(ax, 'YScale'), 'log')
        yin = log10(y / yl(1)) / log10(yl(2) / yl(1)) * pos(4);
    else
        yin = (y - yl(1)) / diff(yl) * pos(4);
    end
    for i = 1:numel(x)
        wh = where;
        if strcmp(where, 'above') && i < numel(x) && (yin(i + 1) - yin(i)) > 0.5 * (xin(i + 1) - xin(i))
            wh = 'aboveLeft';
        end
        kit.valueLabel(ax, x(i), y(i), fmt(y(i)), wh, kit.st.lineLabelGapIn);
    end
end

function asicEndNote(kit, ax, n, yAsic, failLanes)
% Where the ASIC line stops short: say why, at the right edge, hanging from the level of its last point
    if isempty(failLanes) || isempty(yAsic), return; end
    kit.note(ax, n + 0.45, yAsic(end), {sprintf('ASIC: %d lanes', failLanes(1)), 'did not route'}, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
end

function segmentGaps(ax, x, yBounds, bw)
% Thin white line at each boundary inside a stacked bar (yBounds: one column per boundary)
    for i = 1:numel(x)
        for j = 1:size(yBounds, 2)
            plot(ax, x(i) + [-bw, bw] / 2, yBounds(i, j) * [1, 1], '-', 'Color', 'w', 'LineWidth', 1.5);
        end
    end
end

function s = rateStr(v)
    if v < 1
        s = sprintf('%.2f', v);
    else
        s = sprintf('%.1f', v);
    end
end

function s = commaInt(v)
    s = regexprep(sprintf('%d', round(v)), '(\d)(?=(\d{3})+$)', '$1,');
end
