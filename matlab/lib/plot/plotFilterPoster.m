function plotFilterPoster(cfg, outDir)
% plotFilterPoster  Poster Fig. 1: magnitude response of the channel filters as built.
%
%   plotFilterPoster(cfg, outDir)
%
%   AI note: written by Claude (Anthropic) for Ryan Hall's FIR_Filter project.
%
%   Plots the quantized coefficients the hardware uses (fp.hq / 2^fp.SHIFT from
%   data/coefficients/fir_coefficients.mat, written by stage 02), one line per channel,
%   in the same look as the result charts (lib/plot/posterKit.m, cfg.poster). The figure
%   is drawn at cfg.poster.figSize.filter and exported as fig01_filters.png. It has no
%   title or caption: the poster card carries both.
%
%   Requires the Signal Processing Toolbox (freqz).

    coefFile = fullfile(cfg.coefDir, 'fir_coefficients.mat');
    if ~isfile(coefFile)
        error('plotFilterPoster:missingFile', 'Missing %s (run stage 02, run_coefficients, first).', coefFile);
    end
    S   = load(coefFile, 'fp');
    h   = S.fp.hq / 2 ^ S.fp.SHIFT;          % N_TAPS-by-nCh, the response the hardware has
    nCh = size(h, 2);

    kit = posterKit(cfg);
    st  = kit.st;
    c   = st.colors;
    sz  = st.figSize.filter;
    W   = sz(1);
    H   = sz(2);
    left  = 0.78;                            % room for "-100"
    right = 0.22;                            % half of the last x-axis number
    bot   = st.botIn + 0.06;                 % this axis has tick marks, so its numbers sit lower
    ph    = H - bot - st.headIn;
    yHead = bot + ph + 0.22;
    fMax  = cfg.fs / 2 / 1e3;                % kHz

    fig = kit.newFigure('Fig. 1 filter responses', sz);
    ax  = kit.newAxes(fig, [left, bot, W - left - right, ph]);
    yTicks = -100:20:0;
    kit.yAxis(ax, [-100, 10], yTicks, strrep(compose('%d', yTicks(:)), '-', char(8722)));   % true minus signs
    set(ax, 'XLim', [0, fMax], 'XTick', 0:8:fMax);

    items = struct('color', {}, 'label', {}, 'kind', {});
    for ic = nCh:-1:1                        % channel 1 is drawn last, so the darkest line is on top
        col = c.channels{mod(ic - 1, numel(c.channels)) + 1};
        [Hf, f] = freqz(h(:, ic), 1, 16384, cfg.fs);
        plot(ax, f / 1e3, 20 * log10(abs(Hf) + eps), '-', 'Color', col, 'LineWidth', 2.2);
        items(ic) = struct('color', col, 'label', sprintf('Ch %d', ic), 'kind', 'line');
    end
    kit.xTitle(ax, 'Frequency (kHz)', st.xTitleDropIn + 0.06);

    ov = kit.overlay(fig);
    kit.header(ov, st.headerXIn, yHead, '', 'Magnitude (dB)');
    kit.keyRow(ov, W - right, yHead, items);
    kit.export(fig, outDir, 'fig01_filters');
end
