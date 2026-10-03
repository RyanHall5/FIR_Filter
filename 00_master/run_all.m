% run_all.m
% Runs the project's stages in order. Which stages run is set by the flags in
% cfg.run (config/config.m); nothing is hardcoded here.
%
%   01 tap study -> 02 coefficients -> 03 audio prep -> 04 golden model
%   -> 05 STM32 self-test -> 06 hardware demo -> 07 analysis
%   -> 08 visualize -> 09 PPA report
%
% Each stage can also be run on its own: it reads the files the earlier
% stages wrote under data/. Stages 05 and 06 need the STM32 connected, and
% stages 07 and 09 are placeholders, so those flags default to false.

cfg = config();

stages = { ...
    'tapStudy',      '01_tap_study',      'run_tap_study'; ...
    'coefficients',  '02_coefficients',   'run_coefficients'; ...
    'audioPrep',     '03_audio_prep',     'run_audio_prep'; ...
    'goldenModel',   '04_golden_model',   'run_golden_model'; ...
    'stm32Selftest', '05_stm32_selftest', 'run_stm32_selftest'; ...
    'hwDemo',        '06_hw_demo',        'run_hw_demo'; ...
    'analysis',      '07_analysis',       'run_analysis'; ...
    'visualize',     '08_visualize',      'run_visualize'; ...
    'ppaReport',     '09_ppa_report',     'run_ppa_report'};

for k = 1:size(stages, 1)
    if cfg.run.(stages{k, 1})
        runStage(fullfile(cfg.root, stages{k, 2}, [stages{k, 3} '.m']));
    else
        fprintf('\n---------- skipped: %s (cfg.run.%s = false) ----------\n', stages{k, 3}, stages{k, 1});
    end
end

fprintf('\nrun_all complete.\n');
