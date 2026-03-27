function appendMarkersToTRC(trc_in, trc_out, newMarkers, newLabels, newMarkersUnit)
% appendMarkersToTRC  Append markers (Nx3 each) to an existing TRC file (NO BTK).
%
% This avoids BTK TRC label "normalization" bugs (e.g., RMT1 -> RMT collisions).
%
% INPUTS
%   trc_in          : input TRC path (char)
%   trc_out         : output TRC path (char)
%   newMarkers      : cell array {M1,M2,...}; each Mi is [N x 3] double
%   newLabels       : cell array {'RHJC','LHJC',...}; same length as newMarkers
%   newMarkersUnit  : 'm' (default) or 'mm' indicating unit of newMarkers
%
% EXAMPLE
%   newMarkers = {RHJC, LHJC, RKJC, LKJC, RAJC, LAJC};
%   newLabels  = {'RHJC','LHJC','RKJC','LKJC','RAJC','LAJC'};
%   appendMarkersToTRC('ROM-01_before.trc','ROM-01_appended.trc',newMarkers,newLabels,'m');

    if nargin < 5 || isempty(newMarkersUnit)
        newMarkersUnit = 'm';
    end

    if ~ischar(trc_in) || ~ischar(trc_out)
        error('trc_in and trc_out must be char paths.');
    end
    if ~iscell(newMarkers) || ~iscell(newLabels)
        error('newMarkers and newLabels must be cell arrays.');
    end
    if numel(newMarkers) ~= numel(newLabels)
        error('newMarkers and newLabels must have same length.');
    end
    M = numel(newMarkers);

    tab = char(9);

    % =========================
    % Read TRC: first 5 header lines + data lines
    % =========================
    fid = fopen(trc_in,'r');
    if fid < 0, error('Could not open input TRC: %s', trc_in); end

    L1 = fgetl(fid); % PathFileType...
    L2 = fgetl(fid); % DataRate CameraRate ...
    L3 = fgetl(fid); % numeric header values
    L4 = fgetl(fid); % labels header
    L5 = fgetl(fid); % X1 Y1 Z1 ...

    if ~ischar(L5)
        fclose(fid);
        error('TRC invalid/too short: missing header lines.');
    end

    dataLines = {};
    k = 0;
    while true
        tline = fgetl(fid);
        if ~ischar(tline), break; end
        if isempty(tline), continue; end
        k = k + 1;
        dataLines{k,1} = tline; %#ok<AGROW>
    end
    fclose(fid);

    N = numel(dataLines);
    if N == 0
        error('No data lines found in TRC.');
    end

    % =========================
    % Parse header line 3 robustly (tabs or spaces)
    % =========================
    L3s = strrep(L3, tab, ' ');
    v3  = regexp(strtrim(L3s), '\s+', 'split');

    if numel(v3) < 8
        error('Unexpected TRC header format in line 3. Line was: "%s"', L3);
    end

    DataRate       = str2double(v3{1});
    CameraRate     = str2double(v3{2});
    NumFrames_hdr  = str2double(v3{3});
    NumMarkers_old = str2double(v3{4});
    UnitsTRC       = v3{5};          % 'm' or 'mm' typically
    OrigDataRate   = str2double(v3{6});
    OrigStartFrame = str2double(v3{7});
    OrigNumFrames  = str2double(v3{8});

    if isnan(NumMarkers_old)
        error('Could not parse NumMarkers from TRC header line 3.');
    end

    if ~isnan(NumFrames_hdr) && NumFrames_hdr ~= N
        warning('Header NumFrames=%d but file has %d data lines. Using %d.', NumFrames_hdr, N, N);
    end

    % =========================
    % Parse marker labels from line 4 (tab separated with blanks)
    % =========================
    % Remove potential literal "\t" text if present (defensive):
    if ~isempty(strfind(L4, '\t')) %#ok<STREMP>
        % If someone already corrupted it, this warns; we still parse best-effort
        warning('Line 4 contains literal "\\t" sequences; input TRC may be corrupted.');
        L4 = strrep(L4, '\t', tab);
    end

    v4 = regexp(L4, tab, 'split');
    v4 = v4(~cellfun('isempty', v4));

    if numel(v4) < 3
        error('Could not parse marker label line (line 4). Line was: "%s"', L4);
    end

    existingLabels = v4(3:end);
    if numel(existingLabels) ~= NumMarkers_old
        warning('Header NumMarkers=%d but label line has %d. Using %d.', ...
            NumMarkers_old, numel(existingLabels), numel(existingLabels));
        NumMarkers_old = numel(existingLabels);
    end

    % =========================
    % Parse numeric data block
    % =========================
    expectedCols = 2 + 3*NumMarkers_old; % Frame#, Time, then XYZ for each marker
    data = nan(N, expectedCols);

    for i = 1:N
        parts = regexp(dataLines{i}, tab, 'split'); % keep empties
        vals = nan(1, numel(parts));
        for j = 1:numel(parts)
            if isempty(parts{j})
                vals(j) = NaN;
            else
                vals(j) = str2double(parts{j});
            end
        end
        kcols = min(expectedCols, numel(vals));
        data(i,1:kcols) = vals(1:kcols);
    end

    % =========================
    % Validate new markers
    % =========================
    for j = 1:M
        X = newMarkers{j};
        if ~isnumeric(X) || ndims(X) ~= 2 || size(X,2) ~= 3
            error('Each new marker must be numeric [N x 3]. Marker %d is [%d x %d].', ...
                j, size(X,1), size(X,2));
        end
        if size(X,1) ~= N
            error('New marker "%s" has %d frames, but TRC has %d frames.', newLabels{j}, size(X,1), N);
        end
        if ~ischar(newLabels{j}) && ~isstring(newLabels{j})
            error('Each new label must be char or string.');
        end
        newLabels{j} = char(newLabels{j}); %#ok<AGROW>
    end

    % =========================
    % Unit conversion for appended markers to match TRC
    % Assume newMarkers are in newMarkersUnit ('m' default)
    % =========================
    UnitsTRC = lower(strtrim(UnitsTRC));
    newMarkersUnit = lower(strtrim(newMarkersUnit));

    if ~(strcmp(UnitsTRC,'m') || strcmp(UnitsTRC,'mm'))
        warning('TRC Units="%s" not recognized; assuming meters for output.', UnitsTRC);
        UnitsTRC = 'm';
    end
    if ~(strcmp(newMarkersUnit,'m') || strcmp(newMarkersUnit,'mm'))
        error('newMarkersUnit must be ''m'' or ''mm''.');
    end

    % scale factor: newMarkers -> TRC units
    if strcmp(newMarkersUnit,'m') && strcmp(UnitsTRC,'mm')
        scale = 1000;       % m -> mm
    elseif strcmp(newMarkersUnit,'mm') && strcmp(UnitsTRC,'m')
        scale = 0.001;      % mm -> m
    else
        scale = 1;
    end

    appended = [];
    for j = 1:M
        appended = [appended, newMarkers{j} * scale]; %#ok<AGROW>
    end

    data_out = [data, appended];
    allLabels = [existingLabels(:); newLabels(:)];
    NumMarkers_new = numel(allLabels);

    % =========================
    % Rebuild header lines 3/4/5 with REAL tabs (char(9))
    % =========================
    % Line 3 numeric values
    % Keep original Orig* values, update NumFrames and NumMarkers
    if isnan(DataRate), DataRate = CameraRate; end
    if isnan(CameraRate), CameraRate = DataRate; end

    L3_new = sprintf('%.6f\t%.6f\t%d\t%d\t%s\t%.6f\t%d\t%d', ...
        DataRate, CameraRate, N, NumMarkers_new, UnitsTRC, OrigDataRate, OrigStartFrame, OrigNumFrames);

    % Line 4: Frame# Time then label + (tab tab tab) after each label
    L4_new = ['Frame#' tab 'Time'];
    for i = 1:NumMarkers_new
        L4_new = [L4_new tab allLabels{i} tab tab]; %#ok<AGROW>
    end
    L4_new = regexprep(L4_new, '[\t ]+$', '');

    % Line 5: two leading empty fields, then X1 Y1 Z1 ...
    L5_new = [tab tab];
    for i = 1:NumMarkers_new
        L5_new = [L5_new 'X' num2str(i) tab 'Y' num2str(i) tab 'Z' num2str(i) tab]; %#ok<AGROW>
    end
    L5_new = regexprep(L5_new, '[\t ]+$', '');

    % =========================
    % Write output TRC
    % =========================
    fid = fopen(trc_out,'w');
    if fid < 0, error('Could not open output TRC: %s', trc_out); end

    fprintf(fid, '%s\n', L1);
    fprintf(fid, '%s\n', L2);
    fprintf(fid, '%s\n', L3_new);
    fprintf(fid, '%s\n', L4_new);
    fprintf(fid, '%s\n', L5_new);

    % Data: frame#, time, then all marker coords
    for i = 1:N
        fprintf(fid, '%d\t%.6f', round(data_out(i,1)), data_out(i,2));
        fprintf(fid, '\t%.6f', data_out(i,3:end));
        fprintf(fid, '\n');
    end

    fclose(fid);

    % =========================
    % Final sanity check (optional warnings)
    % =========================
    expectedOutCols = 2 + 3*NumMarkers_new;
    if size(data_out,2) ~= expectedOutCols
        warning('Output column count mismatch: got %d, expected %d.', size(data_out,2), expectedOutCols);
    end
end