function appendHelperMarkers(trcFile, pelvisMarker)
    % APPENDHELPERMARKERS takes an existing .trc file and appends the
    % following markers to improve pelvis scaling:
    %   - MIDASIS   (midpoint bewteen LASI/RASI)
    %   - MIDHJC    (midpoint between the hip joint centers)
    %   - PELVC     (pelvis segment center)
    % Input: 
    % trc: full path to trc file
    % pelvisMarker = '{LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'} OR {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSI', 'RPSI'}
    % Note that the order in pelvisMarker is important.

    % Written by: Koppenwallner Laurin Xaver <LaurinXaver.Koppenwallner@oss.at>
    % Edited by Brian Horsak, 23.09.2022
    %----------------------------------------------------------------------------------------------------------------
    
    nHeaderRows = 5;
    trcContent  = importdata(trcFile, '\t', nHeaderRows);
    if ~isa(trcContent, 'struct')
        error('Invalid .trc structure!');
    end

    metaDataRow = trcContent.textdata{3};
    labelRow    = trcContent.textdata{4};
    
    % extract existing data
    labels      = split(labelRow)';
    labels      = labels(~cellfun('isempty', labels)); % remove emtpy cells in case there are some.
    nLabels     = length(labels);
    data        = trcContent.data;
    metaData    = split(metaDataRow);

    try
    colheaders  = trcContent.colheaders;
    catch
        N = size(data,2) - 2; % remove time and frames from count

        % Preallocate cell array (row vector)
        colheaders = cell(1, 2 + 3*N);

        % First two empty cells
        colheaders{1} = '';
        colheaders{2} = '';

        % Fill triplets: 'Xk','Yk','Zk' for k = 1..N
        idx = 3;                       % start filling at position 3
        for k = 1:N
            colheaders{idx}   = sprintf('X%d', k);
            colheaders{idx+1} = sprintf('Y%d', k);
            colheaders{idx+2} = sprintf('Z%d', k);
            idx = idx + 3;
        end
    end
    
    % group coordinate data
    trajectories(:, 1:2, 1)         = trcContent.data(:, 1:2);
    trajectories(:, 3:nLabels, 1)   = trcContent.data(:, 3:3:end);
    trajectories(:, 3:nLabels, 2)   = trcContent.data(:, 4:3:end);
    trajectories(:, 3:nLabels, 3)   = trcContent.data(:, 5:3:end);
    
    % find reference marker data
    lasi = squeeze(trajectories(:, contains(labels, pelvisMarker{1}), :));
    rasi = squeeze(trajectories(:, contains(labels, pelvisMarker{2}), :));
    lhjc = squeeze(trajectories(:, contains(labels, pelvisMarker{3}), :));
    rhjc = squeeze(trajectories(:, contains(labels, pelvisMarker{4}), :));

    % Decided if the SACR must be calculated first from e.g. RPSI LPSI
    if length(pelvisMarker) == 5
    sacr = squeeze(trajectories(:, contains(labels, pelvisMarker{5}), :));
    else
        lpsi = squeeze(trajectories(:, contains(labels, pelvisMarker{5}), :));
        rpsi = squeeze(trajectories(:, contains(labels, pelvisMarker{6}), :));
        sacr = rpsi + (lpsi-rpsi)/2;
    end
    
    % Define helper markers
    asisMidpoint    = rasi + (lasi-rasi)/2;
    hjcMidpoint     = rhjc + (lhjc-rhjc)/2;
    
    d1          = (sacr-asisMidpoint)./vecnorm(sacr-asisMidpoint, 2, 2);
    d2          = (sacr-hjcMidpoint)./vecnorm(sacr-hjcMidpoint, 2, 2);
    ang         = acos(dot(d1, d2, 2));
    dist        = cos(ang) .* vecnorm(sacr-hjcMidpoint, 2, 2);
    pelvCenter  = sacr - d1 .* dist;

    % Decided if the SACR must be calculated first from e.g. RPSI LPSI
    if length(pelvisMarker) == 5
        helperLabels        = {'MIDASIS', 'MIDHJC', 'PELVC'};
        helperMarkers       = [asisMidpoint, hjcMidpoint, pelvCenter];
    else
        helperLabels        = {'MIDASIS', 'MIDHJC', 'PELVC', 'SACR'};
        helperMarkers       = [asisMidpoint, hjcMidpoint, pelvCenter, sacr];
    end
    
    % Append helper markers
    nHelpers        = length(helperLabels);
    nCols           = (length(colheaders)-2)/3;
    helperHeaders   = cell(0, nHelpers*3);
    for i = 1:3:nHelpers*3
        nCols   = nCols + 1;
        col     = num2str(nCols);
        helperHeaders(i:i+2) =  {['X' col], ['Y' col], ['Z' col]};
    end
    
    labels      = [labels helperLabels];
    colheaders  = [colheaders helperHeaders];
    data        = [data helperMarkers];
    
    % edit .trc header 
    metaData{4} = num2str(nCols);
    trcHeader = sprintf('%s\n%s\n%s\n%s\n%s\n', ...
        trcContent.textdata{1, 1}, ...
        trcContent.textdata{2, 1}, ...
        strjoin(metaData, '\t'), ...
        strjoin(labels, '\t\t\t'), ...
        strjoin(colheaders, '\t'));

    % Replace any "\" character with "\\" because otherwise writing the header will fail
    trcHeader = replace(trcHeader,'\','\\');

    % write new file
    fid = fopen(trcFile, 'wt');
    fprintf(fid, trcHeader);
    fclose(fid);
    writematrix(data, trcFile, ...
        'FileType',     'text', ...
        'WriteMode',    'append', ...
        'Delimiter',    'tab');

%% Clear variables except output to prevet memory leak.
clearvars
end

