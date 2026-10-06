function coeffs = designCoefficients(fc, basebandBW, guardBW, numTaps, fs, outDir)
% designCoefficients  Design the channel-select bandpass FIR filter for each
%                      channel using firpm (Parks-McClellan / equiripple).
%
%   coeffs = designCoefficients(fc, basebandBW, guardBW, numTaps, fs, outDir)
%
%   fc          - vector of carrier center frequencies (Hz)
%   basebandBW  - baseband bandwidth per channel (Hz)
%   guardBW     - guard band on each side (Hz)
%   numTaps     - number of FIR taps per filter
%   fs          - sample rate (Hz)
%   outDir      - folder to save fir_coefficients.mat into
%
%   coeffs      - cell array, one coefficient vector per channel

    n = numel(fc);

    passLow  = fc - basebandBW;
    passHigh = fc + basebandBW;
    stopLow  = passLow  - guardBW;
    stopHigh = passHigh + guardBW;

    coeffs = cell(1, n);

    for i = 1:n
        sLow  = max(stopLow(i), 1);
        sHigh = min(stopHigh(i), fs/2 - 1000);

        f = [0, sLow, passLow(i), passHigh(i), sHigh, fs/2] / (fs/2);
        a = [0, 0,    1,          1,           0,     0];

        coeffs{i} = firpm(numTaps - 1, f, a);
        fprintf('  Channel %d (fc=%d Hz): designed %d-tap bandpass filter\n', ...
            i, fc(i), numTaps);
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    save(fullfile(outDir, 'fir_coefficients.mat'), 'coeffs', 'fc', 'fs', 'numTaps');
    fprintf('  Coefficients saved to %s\n', fullfile(outDir, 'fir_coefficients.mat'));
end
