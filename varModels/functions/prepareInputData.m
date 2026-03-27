function [InputData] = prepareInputData(rootWorkingDirectory, workingDirectory, staticC3d, condition, labFlag, markerSet, addPelvisHelperMarker, pelvisMarker4nonUniformScaling, ...
    forceTrcMotCreation, Model2Use, useC3Devents, compute_joint_centers_for_static_trc, jc_base_data)

% This file creates the *.mot and *.trc files from all *.c3d files in the
% working directory. Files are selected based on the string in "condition",
% and by the filename 'static' (e.g. 'static01.c3d')
% e.g. "dynamic01". This file also gets all events and stores the data in
% one output struct.
%
% Three force plates are assumed, you can add lines for addtional forces
% (see line ~65, ff). You will have to add them in the next block
% "Harmonize ..." as well.

% INPUT:
%   - rootWorkingDirectory: folder containing the original c3d etc files
%   - workingDirectory: full path to the folder populating the c3d files
%   - condition: string, substring to find in the c3d file names, which
%     identifies a group of c3d files, e.g. 'walking' for all walking files.
%     This will neglect for example, a static trial.

% Written by:           Brian Horsak - brian.horsak@fhstp.ac.at
% Acknowledgements:     Many thx to Bryce Killian (KU Leuven) for his great
%                       support
%
% Last changed:         02/2021
% -------------------------------------------------------------------------




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Create all paths and write *.trc and *.mot files %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialize results file
paths = struct();

%% Find all files in root working directory relevant for condition
rootWorkingDirectory = fullfile(rootWorkingDirectory);
cd(rootWorkingDirectory);

% Make sure the path name to working directory is ok
workingDirectory = fullfile(workingDirectory);

% Get all files
tmp_c3d = strtrim(string(ls('*.c3d')));
tmp_enf = strtrim(string(ls('*.*Trial*.enf')));

if tmp_enf == ""
    % Get lists of files, and ignore *.enf
    commonFileNames = erase(tmp_c3d,'.c3d'); % remove file ending

    % Exclude static, etc. ...
    commonFileNames = commonFileNames(contains(commonFileNames, condition,'IgnoreCase',true));

    % Make user aware that no *.enf files are there.
    warning off backtrace
    warning(['No *.enf files found in wd <', workingDirectory,'>.', newline, 'I will proceed anyway, but anything beyond inverse kinematics will fail!']);
    warning on backtrace

    % Make file list
    files.c3d = strcat(commonFileNames,'.c3d');
    files.enf = strcat(commonFileNames,'-dummy-no-enf-used-here.c3d');

    % Create enf Flag
    enf_used = false;
else
    % Get lists of files, with *.enf assistance.
    tmpNamesc3d = erase(tmp_c3d,'.c3d'); % remove file ending
    tmpNamesenf = eraseBetween(tmp_enf,'.','.enf','Boundaries','inclusive'); % remove file ending
    
    % Make sure that only *.enf files are listed which have a corresponding *.c3d file
    commonFileNames = intersect(tmpNamesc3d, tmpNamesenf);

    % Exclude static, etc. ...
    commonFileNames = commonFileNames(contains(commonFileNames, condition,'IgnoreCase',true));

    % Rais error in case no dynamic files were found.
    if isempty(commonFileNames)
        error(['Warning: No *.c3d files found in wd <', workingDirectory,'>. Check folder and/or conditions label in start.m!']);
    end

    % Make file list
    files.c3d = strcat(commonFileNames,'.c3d');
    files.enf = tmp_enf(contains(tmp_enf, commonFileNames));

    % Create no enf Flag
    enf_used = true;
end

% Check if static file exists and raise error if not. Otherwise the
% btk toolbox will raise an error with a dialog box preventing the
% workflow to continue.
if ~isfile(staticC3d)
    error(['WARNING: No *.c3d files found in current workingDirectory.' newline ...
        'Check folder and/or conditions label in start.m!' newline]);
end

% ---- Static
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

% Add hip, knee, ankle joint centers to static trc file (for scaling)
if compute_joint_centers_for_static_trc

    % Compute joint centers and add to trc
    add_JC_to_TRC_for_scaling(paths.trc_static, paths.trc_static, jc_base_data);
    disp(">>>> Joint centers were computed and added to the static trc file.")
end

% Add helper markers to *.trc static trial to allow non-uniform scaling of the pelvis
if addPelvisHelperMarker
    appendHelperMarkers(paths.trc_static, pelvisMarker4nonUniformScaling);
end

% ---- Dynamics
% Write *.trc and *.mot files in working directory for condition
idx_c3dFiles = 0;
for i = 1:length(files.c3d)
    
    % Increase index
    idx_c3dFiles = idx_c3dFiles + 1; 
    
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

        %         if true % For now this is set to always cathc errors, but the error messages ar tracked
        %             errN = errN + 1;
        %             failures(errN).cond = condition;
        %             failures(errN).wd = workingDirectory;
        %             failures(errN).err = strcat(getReport(ME), myMsg);
        %             continue % Jump to next iteration of: for i
        %         end
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

v = read_trcFile(char(fullfile(rootWorkingDirectory, paths.trc_static)));

expected  = lower(string(markerSet));
available = lower(string(v.MarkerList));

tf = ismember(expected, available);
if ~all(tf)
    % Report using original casing from markerSet, but filter by missing (case-insensitive)
    missingMask = ~tf;
    missing = string(markerSet(missingMask));  % preserve original case in message

    error('The specified static trial <%s> is missing markers: %s\nWorking directory: <%s>', ...
        staticC3d, strjoin(missing, ', '), workingDirectory);
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
        % Now close acq.
        btkCloseAcquisition(c3d);

        %% Get info about how many valid force plate strikes are in file
        [mot_data, mot_labels, ~] = read_opensim_mot(paths.mot{k});

        if enf_used
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
                if strcmp(enf_cell{enf_idx(j)}(1:3), 'FP8'); FP8 = enf_cell{enf_idx(j)}(5:end); end
                if strcmp(enf_cell{enf_idx(j)}(1:3), 'FP9'); FP9 = enf_cell{enf_idx(j)}(5:end); end
            end

            %% Harmonize different enf file outputs and create FB cell for loop
            if exist('FP1','var') && exist('FP2','var') && exist('FP3','var') && exist('FP4','var') && exist('FP5','var') && exist('FP6','var') && exist('FP7','var') && exist('FP8','var') && exist('FP9','var')
                FPs = {FP1, FP2, FP3, FP4, FP5, FP6, FP7, FP8, FP9};
            elseif exist('FP1','var') && exist('FP2','var') && exist('FP3','var') && exist('FP4','var') && exist('FP5','var') && exist('FP6','var') && exist('FP7','var') && exist('FP8','var')
                FPs = {FP1, FP2, FP3, FP4, FP5, FP6, FP7, FP8};
            elseif exist('FP1','var') && exist('FP2','var') && exist('FP3','var') && exist('FP4','var') && exist('FP5','var') && exist('FP6','var') && exist('FP7','var')
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
        else
            % Create dummy FP to access trial loop.
            FPs = {'NaN'};
        end

        %% Get Event info & more
        % Get metdata from c3d
        %cam_rate = metaData.children.TRIAL.children.CAMERA_RATE.info.values(1,1);
        %startfield = metaData.children.TRIAL.children.ACTUAL_START_FIELD.info.values(1,1);
        %delta = 1/cam_rate * startfield;
        delta = 0; % I have added the delta in c3d2OpenSim - so it does not to be accounted here anymore. If so it would create an offset.

        % Get ID to distingusih different sessions. The idea is to
        % create a unique ID from the folder level above and add it
        % to the name so that if I have later several sessions of
        % the same person the trials will not be overwritten during
        % postprocessing by each other.
        idxSlash = strfind(rootWorkingDirectory,'\');
        tmpId = rootWorkingDirectory(idxSlash(end-1)+1:idxSlash(end)-1);
        tmpId = regexprep(tmpId,'[^a-zA-Z0-9]','');
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

        % Now start trial loop
        for i = 1:nLoops
            if (strcmp(FPs(i),'Invalid') || strcmp(FPs(i),'Auto')) && ~fullTrialGo
                % Do nothing

            elseif (strcmp(FPs(i),'Left') || strcmp(FPs(i),'Right')) || fullTrialGo

                % Get eventes based on lab data
                switch labFlag
                    case {'OSS', 'OSSnoArms', 'FHSTP-BIZ', 'FHSTP', 'FHSTPnoArms', 'FHSTP-pyCGM', 'FHCWnoArms', 'FHCW', 'OSS-pyCGM', 'FHSTP_pyCGM2_5', 'FHSTP_pyCGM2_5noArms', 'UMC_HBMnoArms'}

                        if useC3Devents
                            [InputData, node] = getEventsOSS(mot_data, mot_labels, condition, FPs, k, i, trialCnt, stepCnt, paths, events, delta, InputData);
                        else
                            [InputData, node] = getFirstAndLastFrame(mot_data, mot_labels, condition, FPs, k, i, trialCnt, stepCnt, paths, events, delta, InputData);
                        end

                    case 'ISW'
                        if useC3Devents
                            [InputData, node] = getEventsISW(mot_data, mot_labels, condition, FPs, k, i, trialCnt, paths, stepCnt, events, delta, InputData);
                        else
                            [InputData, node] = getFirstAndLastFrame(mot_data, mot_labels, condition, FPs, k, i, trialCnt, stepCnt, paths, events, delta, InputData);
                        end

                    case 'FF'
                        if useC3Devents
                            [InputData, node] = getEventsFF(mot_data, mot_labels, condition, FPs, k, i, trialCnt, paths, events, delta, InputData);
                        else
                            [InputData, node] = getFirstAndLastFrame(mot_data, mot_labels, condition, FPs, k, i, trialCnt, stepCnt, paths, events, delta, InputData);
                        end

                    otherwise
                        warning('Unknown labFlag: %s in prepareInputData. Skript paused!', labFlag);
                        pause()
                end

                % Get BW from *.mp file or c3d file
                sub_name = metaData.children.SUBJECTS.children.NAMES.info.values();
                InputData.(node).subjectName = strcat(sub_name, '_', idAddOn);
                try
                    InputData.(node).Bodymass = metaData.children.PROCESSING.children.Bodymass.info.values();
                    InputData.(node).BodyHeight = metaData.children.PROCESSING.children.Height.info.values();
                catch
                    [c3dPath, ~] = fileparts(paths.c3d{k});
                    mppath = strcat(c3dPath,'\',sub_name{1,1}, '.mp');
                    fileID = fopen(mppath);
                    mpdata = fscanf(fileID,'%s');

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
% Save and create results folder if necessary

if ~logical(exist(strcat(workingDirectory,'Simulation\'), 'dir'))
    mkdir(strcat(workingDirectory,'Simulation\'))
end
save(strcat(workingDirectory,'Simulation\', char(strrep(sub_name,' ','_')),'-',condition,'-', Model2Use,'-InputDataAllTrials.mat'),'InputData');
disp('>>>>> The *.trc, *.mot files and input data were created.');

end