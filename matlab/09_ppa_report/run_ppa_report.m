% run_ppa_report.m
% Stage 09: FPGA vs ASIC power/performance/area report and the poster's result charts.
%
% AI note: written by Claude (Anthropic) for Ryan Hall's FIR_Filter project.
%
% Reads:  data/ppa_reports/fpga/fpga_ppa_summary.csv  (fpga/scripts/run_fpga_ppa.tcl)
%         data/ppa_reports/asic/asic_ppa_summary.csv  (asic/scripts/run_asic_ppa.py; the ASIC
%         sweep runs in WSL, so copy this file over from the WSL clone first)
% Writes: data/results/09_ppa_report/ppa_summary.csv   one row per platform and LANES value
%         data/results/09_ppa_report/fig06..fig10.pdf/.png  poster Figs. 6 to 10
%
% Clocks per sample, the operating point, colours and figure sizes come from config()
% (cfg.ppa). The per-report parsers in lib/ppa (parseVivado*, parseAsicMetrics) are not used:
% the sweep scripts already reduce every run to one CSV row.

cfg    = config();
outDir = fullfile(cfg.resultsDir, '09_ppa_report');
if ~exist(outDir, 'dir'), mkdir(outDir); end

T = buildPpaTable(cfg);
writetable(T, fullfile(outDir, 'ppa_summary.csv'));

fprintf('run_ppa_report: %d rows (FPGA variant ''%s'', area and power at %g ns)\n', ...
    height(T), cfg.ppa.fpgaVariant, cfg.ppa.refPeriodNs);
disp(T(:, {'platform', 'lanes', 'area', 'areaRel', 'fmaxMHz', 'clocksPerSample', ...
           'maxRateMsps', 'energyPerSample_nJ', 'power_mW'}));

plotPpa(T, cfg, outDir);
fprintf('run_ppa_report: figures and table in %s\n', outDir);
