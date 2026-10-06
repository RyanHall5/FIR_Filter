% run_tap_study.m
% Stage 01: find the minimum FIR tap count for each channel and stopband target,
% checking the response with QUANTIZED coefficients (what the hardware really uses).
% Also shows how the stopband depends on coefficient width, and plots the responses.
%
% Reads:  config() only.
% Writes: data/results/01_tap_study/fir_tap_results.mat
%
% Requires the Signal Processing Toolbox (firpmord, firpm, freqz).

cfg = config();
ts  = cfg.tapStudy;
fs  = cfg.fs;
ch  = channelBands(cfg);
nCh = numel(ch);

As_list  = ts.asList;
Rp_dB    = ts.rippleDb;
coefBits = ts.coefBits;

outDir = fullfile(cfg.resultsDir, '01_tap_study');
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% ---------------- Main table: taps needed at coefBits ----------------
emptyResult = struct('taps', NaN, 'h', [], 'hq', [], 'shift', [], 'As_q', [], 'Rp_q', []);
res = repmat(emptyResult, numel(As_list), nCh);

fprintf('\n=== Minimum taps with %d-bit coefficients (ripple <= %.2f dB p-p) ===\n', coefBits, Rp_dB);
fprintf('%-8s %-16s %6s %12s %12s %8s\n', 'target', 'channel', 'taps', 'stopband(dB)', 'ripple(dB)', 'shift');

for ia = 1:numel(As_list)
    for ic = 1:nCh
        r = findMinTaps(ch(ic), fs, As_list(ia), Rp_dB, coefBits, ts.searchBack, ts.searchFwd);
        res(ia, ic) = r;
        if ~isnan(r.taps)
            fprintf('%-8s %-16s %6d %12.1f %12.3f %8d\n', sprintf('%d dB', As_list(ia)), ch(ic).name, ...
                    r.taps, r.As_q, r.Rp_q, r.shift);
        else
            fprintf('%-8s %-16s %6s   not met within %d taps of the estimate (likely a coefficient-width floor)\n', ...
                    sprintf('%d dB', As_list(ia)), ch(ic).name, 'n/a', ts.searchFwd);
        end
    end
end

%% ---------------- Coefficient-width sweep ----------------
% Takes the unquantized filter found above for asSweep and shows how the
% stopband attenuation depends on coefficient width, with the tap count fixed.
ia = find(As_list == ts.asSweep, 1);
if ~isempty(ia)
    fprintf('\n=== Coefficient width sweep at the %d dB design (taps fixed) ===\n', ts.asSweep);
    fprintf('%-16s', 'channel');
    for b = ts.bitsSweep
        fprintf('%10s', sprintf('%d bit', b));
    end
    fprintf('\n');
    for ic = 1:nCh
        fprintf('%-16s', ch(ic).name);
        if isnan(res(ia, ic).taps)
            fprintf('  (no design found at %d bits to start from)\n', coefBits);
            continue;
        end
        for b = ts.bitsSweep
            [hq, shift] = quantizeCoefs(res(ia, ic).h, b);
            As_b = measureResponse(hq / 2^shift, ch(ic), fs);
            fprintf('%10.1f', As_b);
        end
        fprintf('   (stopband dB)\n');
    end
end

%% ---------------- Summary: tap count for a shared datapath ----------------
fprintf('\n=== Tap count a shared datapath must support (max over channels) ===\n');
for ia = 1:numel(As_list)
    nTaps = [res(ia, :).taps];
    fprintf('%d dB target: %d taps (per channel: %s)\n', As_list(ia), max(nTaps), mat2str(nTaps));
end

%% ---------------- Plot quantized responses for asPlot ----------------
ia = find(As_list == ts.asPlot, 1);
if ~isempty(ia)
    hList = {};  names = {};
    for ic = 1:nCh
        if isnan(res(ia, ic).taps), continue; end
        hList{end+1} = res(ia, ic).hq / 2^res(ia, ic).shift;   %#ok<SAGROW>
        names{end+1} = ch(ic).name;                              %#ok<SAGROW>
    end
    opts = struct('nfft', 16384, 'kHz', true, 'ylim', [-120 5], 'edgesHz', unique([ch.f]));
    plotFilterResponses(hList, names, fs, ...
        sprintf('%d-bit quantized filters, %d dB target', coefBits, ts.asPlot), opts);
end

save(fullfile(outDir, 'fir_tap_results.mat'), 'res', 'ch', 'As_list', 'coefBits', 'fs', 'Rp_dB');
fprintf('\nSaved %s\n', fullfile(outDir, 'fir_tap_results.mat'));
