% run_audio_prep.m
% Stage 03: normalize the source songs, build the composite signal, and write the
% headroom-scaled int16 stream that is sent to the STM32.
%
% Reads:  data/audio/source/<song>.mp3
%         data/coefficients/fir_coefficients.mat   (stage 02; provides fp.INPUT_PEAK)
% Writes: data/audio/normalized/<song>_norm.wav
%         data/audio/composite/composite.wav        (float, for listening/plots)
%         data/audio/composite/<cfg.streamFile>     (int16, headroom-scaled; what gets streamed)

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
    cfg.fc, cfg.basebandBW, cfg.fs);

fprintf('\n--- Scaling for filter headroom and writing stream file ---\n');
coefFile = fullfile(cfg.coefDir, 'fir_coefficients.mat');
assert(exist(coefFile, 'file') == 2, ...
    'run_audio_prep:noCoefficients', ...
    'Missing %s. Run stage 02 (run_coefficients) first.', coefFile);
S = load(coefFile, 'fp');
scaled = scaleForHeadroom(composite, S.fp.INPUT_PEAK);
writeStreamFile(scaled, cfg.sampleBits, fullfile(cfg.compDir, cfg.streamFile));
