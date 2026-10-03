% run_audio_prep.m
% Stage 03: normalize the source songs and build the composite signal.
%
% Reads:  data/audio/source/<song>.mp3
% Writes: data/audio/normalized/<song>_norm.wav
%         data/audio/composite/composite.wav
%
% TODO (placeholders, not called yet): after this stage runs, the composite should be
%   scaled for headroom with scaleForHeadroom(x, fp.INPUT_PEAK) using the limit from
%   stage 02, and written with writeStreamFile. Until then streamToSTM32 quantizes the
%   composite itself, at full scale.

cfg = config();

fprintf('--- Normalizing songs ---\n');
if ~exist(cfg.normDir, 'dir')
    mkdir(cfg.normDir);
end
for i = 1:numel(cfg.songs)
    inFile  = fullfile(cfg.sourceDir, [cfg.songs{i} '.mp3']);
    outFile = fullfile(cfg.normDir, [cfg.songs{i} '_norm.wav']);
    [x, fsOut] = loadAndNormalize(inFile, cfg.fs);
    audiowrite(outFile, x, fsOut);
end

fprintf('\n--- Generating composite signal ---\n');
composite = generateComposite(cfg.songs, cfg.normDir, cfg.compDir, ...
    cfg.fc, cfg.basebandBW, cfg.fs);   %#ok<NASGU>
