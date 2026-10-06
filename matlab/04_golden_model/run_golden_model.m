% run_golden_model.m
% Stage 04: run the bit-exact golden model on a set of test signals, check it
% against MATLAB's filter(), and write hex vectors for the Verilog testbenches.
%
% Reads:  data/coefficients/fir_coefficients.mat (stage 02)
% Writes: data/vectors/  coef_chN.hex, in_<test>.hex, exp_<test>_chN.hex, fir_params.txt

cfg = config();

coefFile = fullfile(cfg.coefDir, 'fir_coefficients.mat');
assert(isfile(coefFile), 'Run stage 02 (run_coefficients) first: %s not found', coefFile);
S   = load(coefFile);
fp  = S.fp;
nCh = size(fp.hq, 2);

fprintf('\n=== Golden model: N_TAPS = %d, COEF_W = %d, SHIFT = %d, ACC_W = %d ===\n', ...
        fp.N_TAPS, fp.COEF_W, fp.SHIFT, fp.ACC_W);

tests = makeGoldenTestSignals(cfg, fp);

if ~exist(cfg.vectorDir, 'dir'), mkdir(cfg.vectorDir); end
nFail = 0;
fprintf('\n=== Golden model checks ===\n');
fprintf('%-12s %-8s %9s %10s %9s %s\n', 'test', 'channel', 'maxErr', 'accBits', 'overflow', 'status');

for it = 1:numel(tests)
    x = tests(it).x(:);
    writeHex(fullfile(cfg.vectorDir, sprintf('in_%s.hex', tests(it).name)), x, 16);
    for ic = 1:nCh
        [y, info] = goldenFir(x, fp.h_half(:, ic), fp.SHIFT, fp.COEF_W);

        ref   = floor(filter(fp.hq(:, ic) / 2^fp.SHIFT, 1, x));   % independent check, exact in doubles
        ideal = filter(fp.h(:, ic), 1, x);                         % unquantized floating-point filter
        maxErr = max(abs(y - ideal));                              % quantization effect, in output LSBs

        ok = isequal(y, ref) && info.overflowCount == 0 && info.accBitsNeeded <= fp.ACC_W;
        status = 'ok';
        if ~ok, nFail = nFail + 1; status = 'FAIL'; end
        fprintf('%-12s ch%-6d %9.2f %5d/%-4d %9d %s\n', tests(it).name, ic, maxErr, ...
                info.accBitsNeeded, fp.ACC_W, info.overflowCount, status);

        writeHex(fullfile(cfg.vectorDir, sprintf('exp_%s_ch%d.hex', tests(it).name, ic)), y, 16);
    end
end
for ic = 1:nCh
    writeHex(fullfile(cfg.vectorDir, sprintf('coef_ch%d.hex', ic)), fp.h_half(:, ic), fp.COEF_W);
end

fid = fopen(fullfile(cfg.vectorDir, 'fir_params.txt'), 'w');
fprintf(fid, 'N_TAPS=%d\nN_HALF=%d\nCOEF_W=%d\nSHIFT=%d\nACC_W=%d\nINPUT_PEAK=%d\n', ...
        fp.N_TAPS, fp.N_HALF, fp.COEF_W, fp.SHIFT, fp.ACC_W, fp.INPUT_PEAK);
fclose(fid);

if nFail == 0
    fprintf('\nALL GOLDEN MODEL CHECKS PASSED. Vectors written to %s\n', cfg.vectorDir);
else
    fprintf('\n%d CHECKS FAILED\n', nFail);
end
