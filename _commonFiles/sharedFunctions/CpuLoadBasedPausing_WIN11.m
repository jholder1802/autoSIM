function CpuLoadBasedPausing_WIN11(thresholdCpuLoad, waitInterval, maxWaitSec)
% CpuLoadBasedPausing_WIN11
% Wait until CPU load falls below a threshold before continuing.
%
% Input:
%   thresholdCpuLoad : CPU load threshold in percent (0–100).
%   waitInterval     : Interval between checks (seconds).
%   maxWaitSec       : (optional) maximum total wait time in seconds.
%                      If exceeded, function stops waiting and returns.
%
% Written by: Brian Horsak
% Modified: 03/2025 (PowerShell Get-Counter, multi-sample, locale-safe)

    if ~ispc
        error('CpuLoadBasedPausing_WIN11 only works on Windows.');
    end
    if nargin < 1 || isempty(thresholdCpuLoad)
        error('thresholdCpuLoad must be specified.');
    end
    if nargin < 2 || isempty(waitInterval) || waitInterval <= 0
        waitInterval = 30; % default: 30 s between checks
    end
    if nargin < 3 || isempty(maxWaitSec) || maxWaitSec <= 0
        maxWaitSec = 60*60*2;  % no hard timeout by default
    end

    % Sanity clamp
    thresholdCpuLoad = max(0, min(100, thresholdCpuLoad));

    pause('on');

    % parameters for CPU sampling
    nSamples       = 3;    % how many samples per check
    sampleInterval = 1.0;  % seconds between samples inside Get-Counter

    tStart = tic;

    while true
        tLoop = tic;

        % -----------------------------------------------------------------
        % 1) Get median CPU load from nSamples samples
        % -----------------------------------------------------------------
        mdnCPULoad = localGetCpuLoadMedian(nSamples, sampleInterval);

        if isnan(mdnCPULoad)
            warning(['Failed to retrieve CPU load via PowerShell. ', ...
                     'Waiting for 5 minutes and then proceeding without further checks.']);
            pause(60*5); % 5 minutes, then exit function
            return;
        end

        % Display status
        fprintf('>>>>> Median CPU Load: %.1f %% ... waiting to fall below %.1f %% to continue! <<<<<\n', ...
                mdnCPULoad, thresholdCpuLoad);

        % -----------------------------------------------------------------
        % 2) Check threshold
        % -----------------------------------------------------------------
        if mdnCPULoad < thresholdCpuLoad
            disp('>>>>> CPU Load threshold reached! Continuing ... <<<<<');
            break;
        end

        % -----------------------------------------------------------------
        % 3) Check max total wait time
        % -----------------------------------------------------------------
        if toc(tStart) > maxWaitSec
            warning(['Maximum wait time of (%.1f s) exceeded. ', ...
                     'Please close all crashed cmd windows and proceed by pressing any button.'], maxWaitSec);
            pause();
			% All cmd windows will be forced to close.
			% closeCmdWindows();
			
            break;
        end

        % -----------------------------------------------------------------
        % 4) Sleep until next check (respecting elapsed time)
        % -----------------------------------------------------------------
        elapsedLoop = toc(tLoop);
        remaining   = waitInterval - elapsedLoop;
        if remaining > 0
            pause(remaining);
        end
    end
end


% =====================================================================
function mdnCpu = localGetCpuLoadMedian(nSamples, sampleInterval)
%localGetCpuLoadMedian  Median CPU load from multiple samples via PowerShell.
%
%   mdnCpu = localGetCpuLoadMedian(nSamples, sampleInterval)
%
% Uses:
%   Get-Counter '\Processor(_Total)\% Processor Time'
% with -SampleInterval and -MaxSamples.
% Returns NaN on failure.

    if nargin < 1 || isempty(nSamples)
        nSamples = 3;
    end
    if nargin < 2 || isempty(sampleInterval)
        sampleInterval = 1.0;
    end

    % Build PowerShell command:
    %   - Sample nSamples times with given interval
    %   - Output all CookedValue numbers (one per line)
    psCmd = sprintf( ...
        ['powershell -NoProfile -Command "', ...
         '(Get-Counter ''\\Processor(_Total)\\%% Processor Time'' ', ...
         '-SampleInterval %g -MaxSamples %d).CounterSamples.CookedValue"'], ...
        sampleInterval, nSamples);

    [status, out] = system(psCmd);

    if status ~= 0
        mdnCpu = NaN;
        return;
    end

    % Clean and split lines
    out = strtrim(out);
    if isempty(out)
        mdnCpu = NaN;
        return;
    end

    lines = regexp(out, '\r\n|\n|\r', 'split');
    values = nan(1, numel(lines));

    for i = 1:numel(lines)
        s = strtrim(lines{i});
        if isempty(s), continue; end

        % Locale handling: convert comma to dot
        s = strrep(s, ',', '.');
        v = str2double(s);
        if ~isnan(v)
            values(i) = v;
        end
    end

    values = values(~isnan(values));
    if isempty(values)
        mdnCpu = NaN;
    else
        mdnCpu = median(values);
    end
end
