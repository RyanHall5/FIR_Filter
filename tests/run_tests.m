% run_tests.m
% Runs every unit test class in tests/cases/ and shows the results.
% Placeholder tests report as filtered (incomplete) until they are implemented.

cfg = config();
results = runtests(fullfile(cfg.root, 'tests', 'cases'));
disp(table(results));
