% run_ppa_report.m
% Stage 09: FPGA vs ASIC power/performance/area report and every chart on the poster.
%
% AI note: written by Claude (Anthropic) for Ryan Hall's FIR_Filter project.
%
% Reads:  data/ppa_reports/fpga/fpga_ppa_summary.csv  (fpga/scripts/run_fpga_ppa.tcl)
%         data/ppa_reports/asic/asic_ppa_summary.csv  (asic/scripts/run_asic_ppa.py; the ASIC
%         sweep runs in WSL, so copy this file over from the WSL clone first)
%         data/coefficients/fir_coefficients.mat      (stage 02; for Fig. 1)
% Writes: data/results/09_ppa_report/ppa_summary.csv  one row per platform and LANES value
%         data/results/09_ppa_report/fig01_filters.png   poster Fig. 1
%         data/results/09_ppa_report/fig06_area.png      poster Fig. 6
%         data/results/09_ppa_report/fig07_speed.png     poster Fig. 7
%         data/results/09_ppa_report/fig08_energy.png    poster Fig. 8
%         data/results/09_ppa_report/fig09_power.png     poster Fig. 9
%
% The PNGs are drawn at the exact size of their slots on the poster and have no title or
% caption (the poster cards carry those), so they can be uploaded as they are. Data settings
% are in cfg.ppa and the shared chart look in cfg.poster (config/config.m). The per-report
% parsers in lib/ppa (parseVivado*, parseAsicMetrics) are not used: the sweep scripts
% already reduce every run to one CSV row.

cfg    = config();
outDir = fullfile(cfg.resultsDir, '09_ppa_report');
if ~exist(outDir, 'dir'), mkdir(outDir); end

T = buildPpaTable(cfg);
writetable(T, fullfile(outDir, 'ppa_summary.csv'));

fprintf('run_ppa_report: %d rows (FPGA variant ''%s'', area and power at %g ns)\n', ...
    height(T), cfg.ppa.fpgaVariant, cfg.ppa.refPeriodNs);
disp(T(:, {'platform', 'lanes', 'area', 'areaRel', 'fmaxMHz', 'clocksPerSample', ...
           'maxRateMsps', 'energyPerSample_nJ', 'power_mW'}));

% The numbers the poster text quotes, straight from the table, to check the wording against
F = sortrows(T(T.platform == "FPGA", :), 'lanes');
A = sortrows(T(T.platform == "ASIC", :), 'lanes');
[shared, iF, iA] = intersect(F.lanes, A.lanes);
if ~isempty(shared)
    speedRatio = F.maxRateMsps(iF) ./ A.maxRateMsps(iA);
    powerRatio = F.power_mW(iF) ./ A.power_mW(iA);
    fprintf('Poster numbers (lanes %s):\n', mat2str(shared'));
    fprintf('  FPGA / ASIC max sample rate:  %s\n', mat2str(round(speedRatio', 1)));
    fprintf('  FPGA / ASIC power at %g MHz:  %s\n', 1e3 / cfg.ppa.refPeriodNs, mat2str(round(powerRatio', 1)));
    fprintf('  ASIC energy per sample vs %d lane(s):  %s %%\n', A.lanes(1), ...
        mat2str(round(100 * (A.energyPerSample_nJ' / A.energyPerSample_nJ(1) - 1))));
    fprintf('  FPGA LUTs:  %s\n', mat2str(F.area'));
end

plotPpa(T, cfg, outDir);
if isfile(fullfile(cfg.coefDir, 'fir_coefficients.mat'))
    plotFilterPoster(cfg, outDir);
else
    fprintf('run_ppa_report: skipped Fig. 1 (no data/coefficients/fir_coefficients.mat; run stage 02).\n');
end
fprintf('run_ppa_report: poster charts and table in %s\n', outDir);
