function plotFilterResponses(hList, names, fs, titleStr, opts)
% plotFilterResponses  Plot the magnitude responses of several filters on one axis.
%
%   plotFilterResponses(hList, names, fs, titleStr)
%   plotFilterResponses(hList, names, fs, titleStr, opts)
%
%   hList     - cell array of coefficient vectors (real-valued)
%   names     - cell array of legend labels, same length as hList
%   fs        - sample rate (Hz)
%   titleStr  - plot title
%   opts      - optional struct, any of:
%                 .nfft     points per response            (default 4096)
%                 .kHz      true = x axis in kHz, else Hz  (default false)
%                 .ylim     [lo hi] in dB                  (default [-100 5])
%                 .edgesHz  vector of band edges (Hz) to mark with dashed lines
%
%   Requires the Signal Processing Toolbox (freqz). Marks band edges with
%   xline, which needs MATLAB R2018b or newer.

    if nargin < 5, opts = struct(); end
    if ~isfield(opts, 'nfft'),    opts.nfft = 4096;       end
    if ~isfield(opts, 'kHz'),     opts.kHz  = false;      end
    if ~isfield(opts, 'ylim'),    opts.ylim = [-100 5];   end
    if ~isfield(opts, 'edgesHz'), opts.edgesHz = [];      end

    colors = {'b', 'r', 'g', 'm', 'c', 'k'};
    scale  = 1;  unitStr = 'Hz';
    if opts.kHz, scale = 1000; unitStr = 'kHz'; end

    figure('Name', titleStr);
    hold on;
    for i = 1:numel(hList)
        [H, f] = freqz(hList{i}, 1, opts.nfft, fs);
        plot(f / scale, 20*log10(abs(H) + eps), colors{mod(i-1, numel(colors)) + 1}, ...
             'DisplayName', names{i});
    end
    if ~isempty(opts.edgesHz)
        xline(opts.edgesHz / scale, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
    end
    xlabel(sprintf('Frequency (%s)', unitStr));
    ylabel('Magnitude (dB)');
    title(titleStr);
    legend show;
    grid on;
    ylim(opts.ylim);
end
