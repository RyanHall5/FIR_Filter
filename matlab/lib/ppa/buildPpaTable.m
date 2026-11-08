function T = buildPpaTable(cfg)
% buildPpaTable  Collect the FPGA and ASIC sweep results into one comparison table.
%
%   T = buildPpaTable(cfg)
%
%   AI note: written by Claude (Anthropic) for Ryan Hall's FIR_Filter project.
%
%   Reads the summary CSVs written by fpga/scripts/run_fpga_ppa.tcl and
%   asic/scripts/run_asic_ppa.py (paths in cfg.ppa) and returns one row per platform
%   (FPGA / ASIC) and LANES value:
%
%     area             FPGA: LUTs; ASIC: standard-cell area (um2), both at cfg.ppa.refPeriodNs
%     areaRel          area relative to the 1-lane design on the same platform
%     fmaxMHz          FPGA: from the tightest clock that met timing (less tool drift);
%                      ASIC: from the cfg.ppa.refPeriodNs run
%     clocksPerSample  measured in simulation (cfg.ppa.clocksPerSample)
%     maxRateMsps      fmaxMHz / clocksPerSample
%     energyPerClk_pJ  FPGA: dynamic power x period at the fmax run (larger values, less
%                      rounding in the 1 mW report); ASIC: total power x period
%     energyPerSample_nJ  energyPerClk_pJ x clocksPerSample
%     power_mW, static_mW, dynamic_mW   at cfg.ppa.refPeriodNs (25 MHz)
%     seq/comb/repair/clock/tap_um2     ASIC area breakdown at cfg.ppa.refPeriodNs
%
%   Lane counts with no finished run are left out (e.g. ASIC 8 lanes did not route).

    p = cfg.ppa;
    mustExist(p.fpgaCsv, 'run fpga/scripts/run_fpga_ppa.tcl');
    mustExist(p.asicCsv, 'copy asic_ppa_summary.csv from the WSL clone (matlab/data/ppa_reports/asic/)');
    F = readtable(p.fpgaCsv, 'TextType', 'string', 'TreatAsMissing', 'NA');
    A = readtable(p.asicCsv, 'TextType', 'string', 'TreatAsMissing', 'NA');

    rows = emptyRow();
    rows(1) = [];
    for i = 1:numel(p.lanes)
        L    = p.lanes(i);
        cps  = p.clocksPerSample(i);
        arch = "lanes" + L;

        f = F(F.architecture == arch & F.variant == string(p.fpgaVariant), :);
        if ~isempty(f)
            rows(end+1) = fpgaRow(f, L, cps, p.refPeriodNs); %#ok<AGROW>
        end
        a = A(A.architecture == arch, :);
        if ~isempty(a) && any(a.period_ns == p.refPeriodNs)
            rows(end+1) = asicRow(a, L, cps, p.refPeriodNs); %#ok<AGROW>
        end
    end
    if isempty(rows)
        error('buildPpaTable:noData', 'No lanes<N> rows found in the PPA summary CSVs.');
    end
    T = struct2table(rows);

    % Area relative to the 1-lane design on the same platform
    T.areaRel = NaN(height(T), 1);
    for plat = ["FPGA", "ASIC"]
        k    = T.platform == plat;
        base = T.area(k & T.lanes == 1);
        if ~isempty(base)
            T.areaRel(k) = T.area(k) / base(1);
        end
    end
end

% -------------------------------------------------------------------------
function s = fpgaRow(f, L, cps, refP)
    s = emptyRow();
    s.platform = "FPGA";
    s.lanes    = L;
    s.clocksPerSample = cps;

    ref = f(f.period_ns == refP, :);
    if ~isempty(ref)
        s.area       = ref.luts(1);
        s.ffs        = ref.ffs(1);
        s.dsps       = ref.dsps(1);
        s.bram       = ref.bram_tiles(1);
        s.power_mW   = ref.total_w(1)   * 1e3;
        s.static_mW  = ref.static_w(1)  * 1e3;
        s.dynamic_mW = ref.dynamic_w(1) * 1e3;
    end

    met = f(f.timing_met == "yes", :);
    if ~isempty(met)
        [~, j] = min(met.period_ns);
        s.fmaxMHz         = met.fmax_mhz(j);
        s.fmaxPeriodNs    = met.period_ns(j);
        s.energyPerClk_pJ = met.dynamic_w(j) * met.period_ns(j) * 1e3;
    end
    s = derive(s);
end

function s = asicRow(a, L, cps, refP)
    s = emptyRow();
    s.platform = "ASIC";
    s.lanes    = L;
    s.clocksPerSample = cps;

    ref = a(a.period_ns == refP, :);
    s.area            = ref.cell_area_um2(1);
    s.fmaxMHz         = ref.fmax_mhz(1);
    s.fmaxPeriodNs    = refP;
    s.energyPerClk_pJ = ref.power_total_w(1) * refP * 1e3;
    s.power_mW        = ref.power_total_w(1) * 1e3;
    s.ffs             = ref.flops(1);
    s.seq_um2         = ref.seq_area_um2(1);
    s.comb_um2        = ref.comb_area_um2(1);
    s.repair_um2      = ref.repair_buf_area_um2(1);
    s.clock_um2       = ref.clock_tree_area_um2(1);
    s.tap_um2         = ref.tap_area_um2(1);
    s = derive(s);
end

function s = derive(s)
    s.maxRateMsps        = s.fmaxMHz / s.clocksPerSample;
    s.energyPerSample_nJ = s.energyPerClk_pJ * s.clocksPerSample / 1e3;
end

function s = emptyRow()
    s = struct('platform', "", 'lanes', NaN, 'area', NaN, 'ffs', NaN, 'dsps', NaN, 'bram', NaN, ...
        'fmaxMHz', NaN, 'fmaxPeriodNs', NaN, 'clocksPerSample', NaN, 'maxRateMsps', NaN, ...
        'energyPerClk_pJ', NaN, 'energyPerSample_nJ', NaN, ...
        'power_mW', NaN, 'static_mW', NaN, 'dynamic_mW', NaN, ...
        'seq_um2', NaN, 'comb_um2', NaN, 'repair_um2', NaN, 'clock_um2', NaN, 'tap_um2', NaN);
end

function mustExist(file, hint)
    if ~isfile(file)
        error('buildPpaTable:missingFile', 'Missing %s (%s).', file, hint);
    end
end
