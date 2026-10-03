function runStage(scriptPath)
% runStage  Run one stage script in its own workspace, so variables from one
%           stage cannot leak into the next when run_all calls them in sequence.
%
%   runStage(scriptPath)
%
%   scriptPath - full path to a stage script, e.g. <root>/01_tap_study/run_tap_study.m

    fprintf('\n========== %s ==========\n', scriptPath);
    run(scriptPath);   % run() evaluates the script in this function's workspace
end
