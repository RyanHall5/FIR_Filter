classdef ReadHexTest < matlab.unittest.TestCase
% ReadHexTest  readHex must read back exactly what writeHex wrote, including negative values.
%
% AI note: written by Claude (Anthropic) at the author's request.

    methods (Test)
        function roundTrip16(testCase)
            v = [-32768; -1; 0; 1; 255; 32767];
            f = [tempname '.hex'];
            testCase.addTeardown(@() delete(f));
            writeHex(f, v, 16);
            testCase.verifyEqual(readHex(f, 16), v);
        end

        function roundTrip14(testCase)
            v = [-8192; -5; 0; 7; 8191];
            f = [tempname '.hex'];
            testCase.addTeardown(@() delete(f));
            writeHex(f, v, 14);
            testCase.verifyEqual(readHex(f, 14), v);
        end

        function readsRepoVector(testCase)
            % The golden impulse input is a single full-scale-ish pulse followed by zeros
            cfg = config();
            f = fullfile(cfg.vectorDir, 'in_impulse.hex');
            testCase.assumeTrue(isfile(f), 'in_impulse.hex not generated yet (run stage 04).');
            v = readHex(f, 16);
            testCase.verifyGreaterThan(numel(v), 100);
            testCase.verifyTrue(all(v >= -32768 & v <= 32767));
        end
    end
end
