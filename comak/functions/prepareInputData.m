function [InputData, errN, failures] = prepareInputData(rootWorkingDirectory, workingDirectory, staticC3d, condition, labFlag, markerSet, addPelvisHelperMarker, pelvisMarker4nonUniformScaling, forceTrcMotCreation, errN, failures, useC3Devents)

% This file creates the *.mot and *.trc files from all *.c3d files in the
% working directory. Files are selected based on the string in "condition",
% and by the filename 'static' (e.g. 'static01.c3d')
% e.g. "dynamic01". This file also gets all events and stores the data in
% one output struct.
%
% Three force plates are assumed, you can add lines for addtional forces
% plates. You will have to add them in the next block
% "Harmonize ..." as well.

% INPUT:
%   - rootWorkingDirectory: folder containing the original c3d etc files
%   - workingDirectory: full path to the folder populating the c3d files
%   - condition: string, substring to find in the c3d file names, which
%     identifies a group of c3d files, e.g. 'walking' for all walking files.
%     This will neglect for example, a static trial.
%   - staticC3d: file path
%   - labFlag: flag indicating which data are used
%   - markerSet: cell array populating marker names

% Written by:           Brian Horsak - brian.horsak@fhstp.ac.at
% Acknowledgements:     Many thx to Bryce Killian (KU Leuven) for his great
%                       support
%
% Last changed:         09/2022
% -------------------------------------------------------------------------

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Create all paths and write *.trc and *.mot files %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialize results file
paths = struct();

%% Find all files in root working directory relevant for condition
rootWorkingDirectory = fullfile(rootWorkingDirectory);
cd(rootWorkingDirectory);

% Make sure the path name to comak working directory is ok
workingDirectory = fullfile(workingDirectory);

% Get all files
tmp_c3d = strtrim(string(ls('*.c3d')));
% tmp_enf = strtrim(string(ls('*.*Trial*.enf')));
tmp_enf = strtrim(string(ls('*.enf')));

% Make sure that only *.enf files are listed which have a corresponding *.c3d file
tmpNamesc3d = erase(tmp_c3d,'.c3d'); % remove file ending
% tmpNamesenf = eraseBetween(tmp_enf,'.','.enf','Boundaries','inclusive'); % remove file ending
tmpNamesenf = erase(tmp_enf,'.enf');
commonFileNames = intersect(tmpNamesc3d, tmpNamesenf);

% Exclude static, etc. ...
% % % added: jh
if strcmp(condition,'Counter-Movement Jump')
    commonFileNames = commonFileNames(and(contains(commonFileNames, condition,'IgnoreCase',true),...
        and(~contains(commonFileNames, 'Left','IgnoreCase',true),~contains(commonFileNames, 'Right','IgnoreCase',true))));
elseif strcmp(condition,'Squatting')
    commonFileNames = commonFileNames(and(contains(commonFileNames, condition,'IgnoreCase',true),...
        and(~contains(commonFileNames, 'Left','IgnoreCase',true),~contains(commonFileNames, 'Right','IgnoreCase',true))));
% % end added: jh
else    
    commonFileNames = commonFileNames(contains(commonFileNames, condition,'IgnoreCase',true));
end

% Make file list
files.c3d = strcat(commonFileNames,'.c3d');
files.enf = tmp_enf(contains(tmp_enf, commonFileNames));

% Check if static file exists and raise error if not. Otherwise the
% btk/ezc3d toolbox will raise an error with a dialog box preventing the
% workflow to continue.
if ~isfile(staticC3d)
    error(['Warning: The specified static trial <', staticC3d,'> does not exist in wd <', workingDirectory,'>!']);
end

% Write *.trc and *.mot files in working directory for static.
if forceTrcMotCreation % check if user wants to force to rewrite *.trc and *.mot files with built-in code
    [paths.trc_static, paths.mot_static] = c3d2OpenSim(staticC3d, labFlag, markerSet, pelvisMarker4nonUniformScaling);

else % expect to have *.trc and *.mot files with same name as the *.c3d file
    paths.trc_static = strcat(staticC3d(1:end-4),'.trc');
    paths.mot_static = strcat(staticC3d(1:end-4),'.mot');

    % Check if files exist, otherwise raise error
    if ~and(isfile(fullfile(rootWorkingDirectory,paths.trc_static)), isfile(fullfile(rootWorkingDirectory,paths.mot_static)))
        error(['Warning: No existing *.trc or *.mot file(s) found for static trial <', staticC3d,'> in wd <', workingDirectory,'>!  Set variable forceTrcMotCreation to <true> to create the necessary files. ']);
    end
end

% Add helper markers to *.trc static trial to allow non-uniform scaling of the pelvis
if addPelvisHelperMarker
    appendHelperMarkers(paths.trc_static, pelvisMarker4nonUniformScaling);
end

% Write *.trc and *.mot files in working directory for condition
idx_c3dFiles = 0;
for i = 1:length(files.c3d)
    idx_c3dFiles = idx_c3dFiles + 1; % increase index
    % Collect paths
    paths.c3d{idx_c3dFiles,:} = char(fullfile(rootWorkingDirectory, files.c3d(idx_c3dFiles)));
    paths.enf{idx_c3dFiles,:} = char(fullfile(rootWorkingDirectory, files.enf(idx_c3dFiles)));

    try
        if forceTrcMotCreation % check if user wants to force to rewrite *.trc and *.mot files with built-in code
            % Write files and collect paths
            [trc, mot] = c3d2OpenSim(char(paths.c3d{idx_c3dFiles}), labFlag, markerSet, pelvisMarker4nonUniformScaling);
            paths.trc{idx_c3dFiles,:} = trc;
            paths.mot{idx_c3dFiles,:} = mot;

        else % expect to have *.trc and *.mot files with same name as the *.c3d file
            tmpFile = char(files.c3d(idx_c3dFiles));
            paths.trc{idx_c3dFiles,:} = char(fullfile(rootWorkingDirectory,strcat(tmpFile(1:end-4),'.trc')));
            paths.mot{idx_c3dFiles,:} = char(fullfile(rootWorkingDirectory,strcat(tmpFile(1:end-4),'.mot')));

            % Make sure the *.mot files have the correct variable heading
            % terminology: ground_torque1 (=wrong) vs. ground_torque_1
            fixMotFileVersion(paths.mot{idx_c3dFiles,:});

            % Check if files exist, otherwise raise error
            if ~and(isfile(fullfile(paths.trc{idx_c3dFiles,:})), isfile(fullfile(paths.mot{idx_c3dFiles,:})))
                error(['Warning: No existing *.trc or *.mot file(s) found for trial <', tmpFile,'> in wd <', workingDirectory,'>!  Set variable forceTrcMotCreation to <true> to create the necessary files. ']);
            end
        end

    catch ME
        % Raise warning
        myMsg = strcat('An error occured while processing file <',files.c3d(idx_c3dFiles),'> in working directory <', rootWorkingDirectory,'>. File was skipped!');
        warning off backtrace
        warning(myMsg);
        warning on backtrace

        % Remove current paths because it had an error
        paths.c3d{idx_c3dFiles,:} = '';
        paths.enf{idx_c3dFiles,:} = '';
        paths.trc{idx_c3dFiles,:} = '';
        paths.mot{idx_c3dFiles,:} = '';

        if true % For now this is set to always cathc errors, but the error messages ar tracked
            errN = errN + 1;
            failures(errN).cond = condition;
            failures(errN).wd = workingDirectory;
            failures(errN).err = strcat(getReport(ME), myMsg);
            continue % Jump to next iteration of: for i
        end
    end
end

% Clean paths from empty cells
paths.c3d = paths.c3d(~cellfun('isempty',paths.c3d));
paths.enf = paths.enf(~cellfun('isempty',paths.enf));
paths.trc = paths.trc(~cellfun('isempty',paths.trc));
paths.mot = paths.mot(~cellfun('isempty',paths.mot));


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Check if all markers for scaling are available %%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This is necessary because if markers in the static are missing, OS will
% still run the scaling but will not scale e.g. the pelvis if a marker for
% scaling is missing.

% v = read_trcFile(char(fullfile(rootWorkingDirectory, paths.trc_static)));
v = read_trcFile(char(paths.trc_static));

if ~(all(ismember(markerSet, v.MarkerList)))
    error(['Warning: The specified static trial <', staticC3d,'> does not contain all necessary markers in wd <', workingDirectory,'>! The following markers are missing: ', strjoin(markerSet(~ismember(markerSet, v.MarkerList)))]);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Create Events %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Init
InputData = struct();
trialCnt = 1;

for k = 1 : length(paths.c3d)
    try
        %% Read c3d file
        c3d = btkReadAcquisition(char(paths.c3d{k}));
        metaData = btkGetMetaData(c3d);
        events = btkGetEvents(c3d);
        % acq will be closed later since the c3d files is used later.

        %% Get info about how many valid force plate strikes are in file
        [mot_data, mot_labels, ~] = read_opensim_mot(paths.mot{k});

        %% Read the enf file to a cell array
        fid = fopen(paths.enf{k},'rt');
        enf_cell = textscan(fid,'%s','Delimiter','\n');
        fclose(fid);
        enf_cell = enf_cell{1,1};

        %% Find information about force plates in file
        % NOTE: if you change this you need to change it also in createExtLoadsFile!
        enf_idx = find(not(cellfun('isempty',strfind(enf_cell,'FP'))));

        % Several force plates are here assumed, add lines for addtional forces
        % plates. You will have to add them in the next block "Harmonize ..." as well

        for j = 1: length(enf_idx)
            if strcmp(enf_cell{enf_idx(j)}(1:3), 'FP1'); FP1 = enf_cell{enf_idx(j)}(5:end); end
            if strcmp(enf_cell{enf_idx(j)}(1:3), 'FP2'); FP2 = enf_cell{enf_idx(j)}(5:end); end
            if strcmp(enf_cell{enf_idx(j)}(1:3), 'FP3'); FP3 = enf_cell{enf_idx(j)}(5:end); end
            if strcmp(enf_cell{enf_idx(j)}(1:3), 'FP4'); FP4 = enf_cell{enf_idx(j)}(5:end); end
            if strcmp(enf_cell{enf_idx(j)}(1:3), 'FP5'); FP5 = enf_cell{enf_idx(j)}(5:end); end
            if strcmp(enf_cell{enf_idx(j)}(1:3), 'FP6'); FP6 = enf_cell{enf_idx(j)}(5:end); end
            if strcmp(enf_cell{enf_idx(j)}(1:3), 'FP7'); FP7 = enf_cell{enf_idx(j)}(5:end); end
        end

        %% Harmonize different enf file outputs and create FB cell for loop
        if exist('FP1','var') && exist('FP2','var') && exist('FP3','var') && exist('FP4','var') && exist('FP5','var') && exist('FP6','var') && exist('FP7','var')
            FPs = {FP1, FP2, FP3, FP4, FP5, FP6, FP7};
        elseif exist('FP1','var') && exist('FP2','var') && exist('FP3','var') && exist('FP4','var') && exist('FP5','var') && exist('FP6','var')
            FPs = {FP1, FP2, FP3, FP4, FP5, FP6};
        elseif exist('FP1','var') && exist('FP2','var') && exist('FP3','var') && exist('FP4','var') && exist('FP5','var')
            FPs = {FP1, FP2, FP3, FP4, FP5};
        elseif exist('FP1','var') && exist('FP2','var') && exist('FP3','var') && exist('FP4','var')
            FPs = {FP1, FP2, FP3, FP4};
        elseif exist('FP1','var') && exist('FP2','var') && exist('FP3','var')
            FPs = {FP1, FP2, FP3};
        elseif exist('FP1','var') && exist('FP2','var')
            FPs = {FP1, FP2};
        elseif exist('FP1','var')
            FPs = {FP1};
        end

        % Replace other version of enf file info with the standard used here
        FPs = strrep(FPs, 'FPL','Left');
        FPs = strrep(FPs, 'FPR','Right');
        FPs = strrep(FPs, 'FPI','Invalid');


        %% Get Event info & more
        % Get marker data for mSEBT event detection
        mkrs = btkGetMarkers(c3d);
        % Now close acq.
        btkCloseAcquisition(c3d);

        % Get metdata from c3d
        % cam_rate = metaData.children.TRIAL.children.CAMERA_RATE.info.values(1,1); % % auskommentiert, jh (12.11.25)
        % startfield = metaData.children.TRIAL.children.ACTUAL_START_FIELD.info.values(1,1);
        % delta = 1/cam_rate * startfield;
        delta = 0; % I have added the delta in c3d2OpenSim - so it does not need to be accounted here anymore. If so it would create an offset.

        % Get ID to distingusih different sessions. The idea is to
        % create a unique ID from the folder level above and add it
        % to the name so that if I have later several sessions of
        % the same person the trials will not be overwritten during
        % postprocessing by each other.
        idxSlash = strfind(rootWorkingDirectory,'\');
        % tmpId = rootWorkingDirectory(idxSlash(end-1)+1:idxSlash(end)-1); % % % jh (05.02.2025):changed     
        tmpId = rootWorkingDirectory(idxSlash(end-2)+1:idxSlash(end-1)-1); % % % jh (05.02.2025):changed
        tmpId = regexprep(tmpId,'[^a-zA-Z0-9]',''); % % % jh (05.02.2025):changed
        if length(tmpId) < 10
            idAddOn = tmpId;
        else
            stepCnt = round(length(tmpId)/10); % make sure the ID is not too long
            idAddOn = tmpId(1:stepCnt:end);
        end

        % Loop through steps
        stepCnt = 1; % used to track the step count per trial

        % Check if full trial should be processed or if trial will be
        % processed based on events.
        if useC3Devents
            nLoops = length(FPs); % FP1 ... FP5
            fullTrialGo = false;
        else
            nLoops = 1;
            fullTrialGo = true;
        end

        for i = 1 : nLoops
            if (strcmp(FPs(i),'Invalid') || strcmp(FPs(i),'Auto')) && ~fullTrialGo
                % Do nothing

            elseif (strcmp(FPs(i),'Left') || strcmp(FPs(i),'Right')) || fullTrialGo

                % Get events based on lab data
                switch labFlag
                    case {'OSS', 'OSSnoArms', 'FHSTP-BIZ', 'FHSTPnoArms', 'FHSTP', 'LKHG_Cleve', 'LKHG_PiG'}

                        if useC3Devents
                            [InputData, node] = getEventsOSS(mot_data, mot_labels, condition, FPs, k, i, trialCnt, stepCnt, paths, events, delta, InputData, mkrs, cam_rate);
                        else
                            [InputData, node] = getFirstAndLastFrame(mot_data, mot_labels, condition, FPs, k, i, trialCnt, stepCnt, paths, events, delta, InputData);
                        end

                    case 'ISW'
                        if useC3Devents
                            [InputData, node] = getEventsISW(mot_data, mot_labels, condition, FPs, k, i, trialCnt, stepCnt, paths, events, delta, InputData);
                        else
                            [InputData, node] = getFirstAndLastFrame(mot_data, mot_labels, condition, FPs, k, i, trialCnt, stepCnt, paths, events, delta, InputData);
                        end
                    case {'PLUS_COD_noArms','PLUS_SportsMarkerset_noArms','PLUS_SportsMarkerset_noArms_newFPs'}% % jh (23.01.2025): contains.. added
                        if useC3Devents
                            mkrs_rate = metaData.children.POINT.children.RATE.info.values;
                            mot_rate = metaData.children.ANALOG.children.RATE.info.values;
                            [InputData, node] = getEventsPLUS(mot_data, mot_labels, condition, FPs, k, i, trialCnt, stepCnt, paths, events, delta, InputData, mkrs, mot_rate, mkrs_rate);
                        else
                            [InputData, node] = getFirstAndLastFrame(mot_data, mot_labels, condition, FPs, k, i, trialCnt, stepCnt, paths, events, delta, InputData);
                        end
                end

                % Get BW and height from *.mp file or c3d file
                % sub_name = metaData.children.SUBJECTS.children.NAMES.info.values();
                % % changed (jh, 28.01.2025)
                sub_name = metaData.children.PROCESSING.children.ID.info.values{1, 1};
                InputData.(node).subjectName = strcat(sub_name, '_', idAddOn);
                try
                    % InputData.(node).Bodymass = metaData.children.PROCESSING.children.Bodymass.info.values();
                    InputData.(node).Bodymass = metaData.children.PROCESSING.children.Weight.info.values(); % % changed (jh, 28.01.2025)
                    InputData.(node).BodyHeight = metaData.children.PROCESSING.children.Height.info.values();
                catch
                    [c3dPath, ~] = fileparts(paths.c3d{k});
                    try
                        mppath = strcat(c3dPath,'\',sub_name{1,1}, '.mp');
                        fileID = fopen(mppath);
                        mpdata = fscanf(fileID,'%s');
                    catch
                        mppath = strcat(c3dPath,'\Subject_descr.mp');           %Adaption for LKHG
                        fileID = fopen(mppath);
                        mpdata = fscanf(fileID,'%s');
                    end

                    % Close fid in case it was opened
                    if exist('fileID', 'var')
                        fclose(fileID);
                    end

                    % Get body mass
                    bmstruct = searchcmd(mpdata,'Bodymass=','$');
                    InputData.(node).Bodymass = str2double(bmstruct{1,1});

                    % Get height
                    bhstruct = searchcmd(mpdata,'Height=','$');
                    bodyHeight = str2double(bhstruct{1,1});
                    InputData.(node).BodyHeight = str2double(bhstruct{1,1});

                    % Check if height is reasonable
                    if  (bodyHeight > 1.3) && (bodyHeight < 2.3)
                        error('>>>>> Warning body height out of reasonable bounds for adults <1.3 - 2.3>!');
                    end

                end

                % Get hip width from mp file.
                try
                    [c3dPath, ~] = fileparts(paths.c3d{k});
                    mppath = strcat(c3dPath,'\',sub_name{1,1}, '.mp');
                    fileID = fopen(mppath);
                    mpdata = fscanf(fileID,'%s');

                    % Get body mass
                    tmpStruct = searchcmd(mpdata,'InterAsisDistance=','$');
                    InputData.(node).HipWidth = str2double(tmpStruct{1,1});

                catch
                    InputData.(node).HipWidth = NaN;
                end

                % Increase trial count.
                trialCnt = trialCnt + 1;
                stepCnt = stepCnt + 1;
            end
        end
    catch
        [~,currFileName,~] = fileparts(paths.c3d{k});
        warning(['>>>>> An error occured in trial <', currFileName,'>. Skipped trial!']);
    end
end
% Save and create JAM folder if necessary

if ~logical(exist(strcat(workingDirectory,'JAM\'), 'dir'))
    mkdir(strcat(workingDirectory,'JAM\'))
end
save(strcat(workingDirectory,'JAM\', char(strrep(sub_name,' ','_')),'-',condition,'-JAM-InputDataAllTrials.mat'),'InputData');
disp('>>>>> The *.trc, *.mot files and input data were created / checked.');

%% Clear variables except output to prevet memory leak.
clearvars -except InputData errN failures
end