% run_visualize.m
% Stage 08: every visual verification check across the pipeline: normalized
% song waveforms/spectra, source-vs-normalized comparisons, the composite
% signal spectrum, channel filter frequency responses, and filtered channel
% outputs.
%
% Entirely driven by config() - no hardcoded constants here. Run this AFTER
% stages 02 and 03 have produced the coefficient and audio files.
%
% Reads:  data/audio/{source,normalized,composite}, data/coefficients/fir_coefficients.mat

cfg = config();

% =========================================================================
% ---- Normalized song waveform + spectrum, and source-vs-normalized ----
% =========================================================================
for i = 1:numel(cfg.songs)
    name = cfg.songs{i};

    [x, fs] = audioread(fullfile(cfg.normDir, [name '_norm.wav']));
    t = (0:length(x)-1) / fs;

    figure('Name', [name ' - waveform']);
    plot(t, x);
    xlabel('Time (s)');
    ylabel('Amplitude');
    title([name ' normalized waveform (first 5 s)']);
    xlim([0 5]);

    figure('Name', [name ' - normalized spectrum']);
    plotSpectrum(x, fs, [name ' normalized spectrum (' num2str(fs) ' Hz)']);

    [xSrc, fsSrc] = audioread(fullfile(cfg.sourceDir, [name '.mp3']));
    if size(xSrc, 2) > 1
        xSrc = mean(xSrc, 2);
    end

    figure('Name', [name ' - source vs normalized']);
    subplot(2,1,1);
    plotSpectrum(xSrc, fsSrc, [name ' source (' num2str(fsSrc) ' Hz)']);
    subplot(2,1,2);
    plotSpectrum(x, fs, [name ' normalized (' num2str(fs) ' Hz)']);
end

% =========================================================================
% ---- Composite signal spectrum ----
% =========================================================================
[composite, fsComp] = audioread(fullfile(cfg.compDir, 'composite.wav'));
if fsComp ~= cfg.fs
    error('Composite sample rate (%d) does not match config fs (%d)', fsComp, cfg.fs);
end

figure('Name', 'Composite signal spectrum');
plotSpectrum(composite, cfg.fs, 'Composite signal (all channels summed)');

% =========================================================================
% ---- Channel filter frequency responses ----
% =========================================================================
loaded = load(fullfile(cfg.coefDir, 'fir_coefficients.mat'));
coeffs = loaded.coeffs;

names = cell(1, numel(coeffs));
for i = 1:numel(coeffs)
    names{i} = sprintf('Ch%d (fc=%d Hz)', i, cfg.fc(i));
end
plotFilterResponses(coeffs, names, cfg.fs, 'Channel-select FIR filter frequency responses');

% =========================================================================
% ---- Filtered channel outputs (each filter applied to the composite) ----
% =========================================================================
figure('Name', 'Filtered channel outputs');
for i = 1:numel(coeffs)
    y = filter(coeffs{i}, 1, composite);

    subplot(numel(coeffs), 1, i);
    plotSpectrum(y, cfg.fs, sprintf('Channel %d isolated (fc=%d Hz)', i, cfg.fc(i)));
end
