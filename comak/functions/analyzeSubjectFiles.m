function subResults = analyzeSubjectFiles(workingDirectory, rootDirectory, path2setupFiles, condition, prefix, timeNormFlag, trialType, processVtp)
%% Collect and analyze JAM output from one subject
% This function searches for all relevant comak output files for one
% subject and single condition and creates summarized plots and a results
% summary file.
%
% INPUT:
%   - workingDirectory: full path of the working directory where all basic
%     c3d files are stored
%   - rootDirectory: e.g.  top level dir containing alls working dirs
%   - sujectname: string, names of the subject (e.g. 'ID01 or 'UncleSam')
%   - condition: string, name of the condition (e.g. walking, dynamic, ...)
%   - prefix: string, used prefix (e.g. 'test')
%   - timeNormFlag: indicates if all data will be time-normalized to 100%
%   - trialType: used to adjust plots for walking or other movements

% Written by:           Brian Horsak - brian.horsak@fhstp.ac.at
% Modified by:          Bernhard Guggenberger - bernhard.guggenberger2@fh-joanneum.at
% Acknowledgements:     Many thx to Bryce Killian (KU Leuven) for his great
%                       support
%
% Last changed:         06/2023
% -------------------------------------------------------------------------

%% Some house keeping variables
line_width = 1.2;
path.NormKCF = strcat(path2setupFiles,'..\..\_commonFiles\normData\OrthoLoad\OrthoLoad_KCFnorm.mat');
path.NormEMG = strcat(path2setupFiles,'..\..\_commonFiles\normData\Lencioni_2019\Lencioni2019_EMGnorm.mat');

%% Define variables of interest
% Select muscle activations
msls = {'addbrev_','addlong_','addmagProx_','addmagMid_','addmagDist_','addmagIsch_',...
    'bflh_','bfsh_','edl_','ehl_','fdl_','fhl_','gaslat_','gasmed_','gem_','glmax1_',...
    'glmax2_','glmax3_','glmed1_','glmed2_','glmed3_','glmin1_','glmin2_','glmin3_',...
    'grac_','iliacus_','pect_','perbrev_','perlong_','pertert_','piri_','psoas_',...
    'quadfem_','recfem_','sart_','semimem_','semiten_','soleus_','tfl_','tibant_',...
    'tibpost_','vasint_','vaslat_','vasmed_'};

% Muscle subset for which I have normdata
msls_subNorm = {'soleus_','gasmed_','recfem_', ...
    'glmax1_', 'bfsh_', 'bflh_', ...
    'perlong_', 'vasmed_', 'tibant_'};

% Norm muscles
msls_norm = {'Soleus','Gastrocnemius_Medialis','Rectus_Femoris', ...
    'Gluteus_Maximus', 'Biceps_Femoris', 'Biceps_Femoris',  ...
    'Peroneus_Longus','Vastus_Medialis','Tibialis_Anterior'};

% Select contact forces
tf_contactF = {'tf_contact.casting.total.contact_force_x','tf_contact.casting.total.contact_force_y','tf_contact.casting.total.contact_force_z'};

%% Load InputData File
InputFile = dir(strcat(workingDirectory,'JAM\','*', condition,'*InputData*.*'));
load(horzcat(InputFile.folder,'\', InputFile.name));

% Load Model MetaData Info
SubjInfo = dir(strcat(workingDirectory,'JAM\','*', condition,'*SubjInfo*.*'));
load(horzcat(SubjInfo.folder,'\', SubjInfo.name));

% Get file names
FileNames_InputData = fieldnames(InputData);
subjectName = char(strrep(InputData.(FileNames_InputData{1}).subjectName,' ','_'));

%% Find all relevant files
% Find all force reporter files - I want to get everything except the muscle in here. The muscle forces in the ForceReport are wrong!
Folder = strcat(workingDirectory,'JAM\');
[folderPaths, folderNames] = getAllFoldersToAnalyze(Folder, prefix, condition);
filesForce = strcat(folderPaths,'\jam\',folderNames,'__ForceReporter_forces.sto');
filesForce = filesForce(isfile(filesForce)); % get only files that exist

% Find all muscle activation files
Folder = strcat(workingDirectory,'JAM\');
[folderPaths, folderNames] = getAllFoldersToAnalyze(Folder, prefix, condition);
filesMuscleAct = strcat(folderPaths,'\comak\',folderNames,'__activation.sto');
filesMuscleAct = filesMuscleAct(isfile(filesMuscleAct)); % get only files that exist

% Find all muscle forces files
Folder = strcat(workingDirectory,'JAM\');
[folderPaths, folderNames] = getAllFoldersToAnalyze(Folder, prefix, condition);
filesMuscleForce = strcat(folderPaths,'\comak\',folderNames,'__force.sto');
filesMuscleForce = filesMuscleForce(isfile(filesMuscleForce)); % get only files that exist

% Find all inverse-dynamics files
Folder = strcat(workingDirectory,'JAM\');
[folderPaths, folderNames] = getAllFoldersToAnalyze(Folder, prefix, condition);
filesInverseDynamics = strcat(folderPaths,'\inverse-dynamics\',folderNames,'_inverse-dynamics.sto');
filesInverseDynamics = filesInverseDynamics(isfile(filesInverseDynamics)); % get only files that exist

% Find all comak kinematics files
Folder = strcat(workingDirectory,'JAM\');
[folderPaths, folderNames] = getAllFoldersToAnalyze(Folder, prefix, condition);
filesKinematicsComak = strcat(folderPaths,'\comak\',folderNames,'__values.sto');
filesKinematicsComak = filesKinematicsComak(isfile(filesKinematicsComak)); % get only files that exist

% Find all IK kinematics files
Folder = strcat(workingDirectory,'JAM\');
[folderPaths, folderNames] = getAllFoldersToAnalyze(Folder, prefix, condition);
filesInvKinematics = strcat(folderPaths,'\inverse-kinematics\',folderNames,'_IK_motion_file.mot');
filesInvKinematics = filesInvKinematics(isfile(filesInvKinematics)); % get only files that exist

% Find all IK error location results
Folder = strcat(workingDirectory,'JAM\');
[folderPaths, folderNames] = getAllFoldersToAnalyze(Folder, prefix, condition);
filesErrorIKLocs = strcat(folderPaths,'\', folderNames,'_ErrorStruct.mat');
filesErrorIKLocs = filesErrorIKLocs(isfile(filesErrorIKLocs)); % get only files that exist

% Find all Force Reporter files
Folder = strcat(workingDirectory,'JAM\');
[folderPaths, folderNames] = getAllFoldersToAnalyze(Folder, prefix, condition);
filesForceReporter = strcat(folderPaths,'\analyze\',folderNames,'_ForceReporter_forces.sto');
filesForceReporter = filesForceReporter(isfile(filesForceReporter)); % get only files that exist

% Find all Body Kinematics files
Folder = strcat(workingDirectory,'JAM\');
[folderPaths, folderNames] = getAllFoldersToAnalyze(Folder, prefix, condition);
filesBodyKinematics = strcat(folderPaths,'\analyze\',folderNames,'_BodyKinematics_pos_global.sto');
filesBodyKinematics = filesBodyKinematics(isfile(filesBodyKinematics)); % get only files that exist

%% Check if files were found otherwise skip postprocessing
% Check if File lists are empty
if isempty(filesInvKinematics)
    warning(strcat('No file(s) found in <',workingDirectory , '> for condition <', condition,'> and prefix <', prefix,'>.'));
else

    %% Check if all file lists have the same size
    % Deal unequal file lists
    tmp = strrep(filesInvKinematics, strcat(workingDirectory,'JAM\'), ''); % start with the results which has highest chances to have results. This will help that I do not miss data during dealing!

    cnt = 1;
    for k = 1 : length(tmp)
        idxSlash = strfind(tmp{k},'\');
        idxSlash = idxSlash(1) -1;
        currentTrialName = tmp{k}(1:idxSlash);

        if any(contains(filesForce, currentTrialName)) && ...
                any(contains(filesMuscleAct, currentTrialName)) && ...
                any(contains(filesMuscleForce, currentTrialName)) && ...
                any(contains(filesInvKinematics, currentTrialName)) && ...
                any(contains(filesKinematicsComak, currentTrialName)) && ...
                any(contains(filesInverseDynamics, currentTrialName)) && ...
                any(contains(filesErrorIKLocs, currentTrialName)) && ...
                any(contains(filesForceReporter, currentTrialName)) && ...
                any(contains(filesBodyKinematics, currentTrialName))

            % Deale lists
            filesForce_dealed{cnt,1} = filesForce{find(contains(filesForce, currentTrialName))};
            filesMuscleAct_dealed{cnt,1} = filesMuscleAct{find(contains(filesMuscleAct, currentTrialName))};
            filesMuscleForce_dealed{cnt,1} = filesMuscleForce{find(contains(filesMuscleForce, currentTrialName))};
            filesInvKinematics_dealed{cnt,1} = filesInvKinematics{find(contains(filesInvKinematics, currentTrialName))};
            filesKinematicsComak_dealed{cnt,1} = filesKinematicsComak{find(contains(filesKinematicsComak, currentTrialName))};
            filesInverseDynamics_dealed{cnt,1} = filesInverseDynamics{find(contains(filesInverseDynamics, currentTrialName))};
            filesErrorIKLocs_dealed{cnt,1} = filesErrorIKLocs{find(contains(filesErrorIKLocs, currentTrialName))};
            filesForceReporter_dealed{cnt,1} = filesForceReporter{find(contains(filesForceReporter, currentTrialName))};
            filesBodyKinematics_dealed{cnt,1} = filesBodyKinematics{find(contains(filesBodyKinematics, currentTrialName))};

            % Increase cnt
            cnt = cnt + 1;
        end
    end

    % Check again to make sure
    lengths2check = [length(filesForce_dealed), length(filesMuscleAct_dealed), length(filesMuscleForce_dealed), ...
        length(filesInvKinematics_dealed), length(filesKinematicsComak_dealed), length(filesInverseDynamics_dealed), ...
        length(filesForceReporter_dealed), length(filesBodyKinematics_dealed), length(filesErrorIKLocs_dealed)];

    if all(diff(lengths2check) == 0)
        disp('>>>>> File lists look ok!')
    else
        warning('Number of files is still unequal for results categories! Please check!')
        return
    end

    %% Initialize the results struct
    resultsAll_perTrial = struct(); % initialize struct
    results_perSub = struct(); % initialize struct
    sideS = {'r','l'};
    for ss = 1 : 2
        results_perSub.(sideS{ss}) = struct(); % initialize
        results_perSub.(sideS{ss}).ContactForces = struct(); % initialize
        results_perSub.(sideS{ss}).MuscleActivations = struct(); % initialize
        results_perSub.(sideS{ss}).MuscleForces = struct(); % initialize
        results_perSub.(sideS{ss}).KinematicsComak = struct(); % initialize
        results_perSub.(sideS{ss}).InverseKinematics = struct(); % initialize
        results_perSub.(sideS{ss}).InverseDynamics = struct(); % initialize
        results_perSub.(sideS{ss}).ContactPressure = struct(); % initialize
        results_perSub.(sideS{ss}).BodyKinematics = struct(); % initialize
        results_perSub.(sideS{ss}).GRFs = struct(); % initialize
        results_perSub.(sideS{ss}).Events = struct(); % initialize
        results_perSub.(sideS{ss}).IKerrors = struct(); % initialize
        results_perSub.(sideS{ss}).ReserveActivation = struct(); % initialize
        results_perSub.(sideS{ss}).ForceReserve = struct(); % initialize
        results_perSub.(sideS{ss}).ResidualForcesPelvis = struct(); % initialize
        % Note that the metaData (subjInfo) are added at the end of the script
    end


    %% Read the Pressure data and store it in final struct
    % Pressure *.vtp files: it is assuemd that when the forceReporter File is
    % available also *.vtp results are available.

    % Only process vtp files if user selected it
    if processVtp

        %Get shape of medial and lateral facette of patella cartilage
        %Matrix accuracy varies the accuracy of this function.
        matrix_accuracy = 0.0001;
        %For left side
        path_patella = fullfile(workingDirectory,'Geometry','lenhart2015-R-patella-cartilage_mirror.stl');
        [idxMedPtsLeft, idxLatPtsLeft] = getMedLatFacettes(path_patella,matrix_accuracy,'l');

        %For right side
        path_patella = fullfile(workingDirectory,'Geometry','lenhart2015-R-patella-cartilage.stl');
        [idxMedPtsRight, idxLatPtsRight] = getMedLatFacettes(path_patella,matrix_accuracy,'r');

        % Define count for column index over all trials
        cntRight = 1;
        cntLeft = 1;
        for i = 1 : length(filesForce_dealed)

            % Extract current file name of the loop and delete trailing and leading "_". Also get rid of prefix
            %trial_name_tmp = strip(strip(erase(FileListForce(i).name(1:strfind(FileListForce(i).name ,'__ForceReporter')-1),prefix),'_'),'-');
            %name_tmp = trial_name_tmp(strfind(trial_name_tmp,condition):end); %get rid of prefix if prefix was not defined specifically
            stop_strIdx = strfind(filesForce_dealed{i} ,'jam')-2;
            tmp = strfind(filesForce_dealed{i}(1:stop_strIdx),'\');
            start_strIdx = tmp(end)+1;
            trial_name_tmp = strip(erase(filesForce_dealed{i}(start_strIdx:stop_strIdx),prefix),'_');
            name_tmp = trial_name_tmp(strfind(lower(trial_name_tmp),lower(condition)):end); %get rid of prefix if prefix was not defined specifically


            % Find in InputData trial names to get side and BW
            for k = 1 : length(FileNames_InputData)
                if contains(FileNames_InputData{k},name_tmp); trialNameInputData = FileNames_InputData{k}; end
            end

            % Process the *.vtp files to get pressure vars table
            [folderVtp,~,~] = fileparts(filesForce_dealed{i}); % Find folder
            %folderVtp = fullfile(folderVtp, 'jam-ascii'); % define the subfolder
            geometryPath = fullfile(workingDirectory,'Geometry'); % Geometry path to scaled geometries

            outTmp = vtp_get_pressure_vars(folderVtp, geometryPath, InputData.(trialNameInputData).Bodymass * 9.81, InputData.(trialNameInputData).Side(1), idxMedPtsLeft, idxLatPtsLeft, idxMedPtsRight, idxLatPtsRight);

            % Write to all struct
            resultsAll_perTrial.(trial_name_tmp).PressureForceVtp = outTmp;

            % Write results struct
            sideTmp = lower(InputData.(trialNameInputData).Side(1));
            sTable = table2struct(outTmp);
            fnTable = fieldnames(sTable);
            for idxsT = 1 : length(fnTable)
                % Add left or right info to fn name
                currentFnTable = strcat(fnTable{idxsT},'_', sideTmp);

                % Set side specific count and then add + 1
                if strcmp(sideTmp, 'r'); cnt = cntRight; end
                if strcmp(sideTmp, 'l'); cnt = cntLeft; end

                % Write results
                numFrames = height(outTmp); % get number of frames
                if ~isfield(results_perSub.(sideTmp).ContactPressure, currentFnTable)
                    if timeNormFlag
                        results_perSub.(sideTmp).ContactPressure.(currentFnTable) = NaN(101,500); % DIRTY HACK: I just used a very long number because I don not know otherwise how to allocate the data
                        results_perSub.(sideTmp).ContactPressure.(currentFnTable)(1:101,cnt) = interpft(outTmp.(fnTable{idxsT}),101); %create variable the first time
                    else
                        results_perSub.(sideTmp).ContactPressure.(currentFnTable) = NaN(500,500); % DIRTY HACK: I just used a very long number because I don not know otherwise how to allocate the data
                        results_perSub.(sideTmp).ContactPressure.(currentFnTable)(1:numFrames,cnt) = padarray(outTmp.(fnTable{idxsT}),numFrames-length(outTmp.(fnTable{idxsT})),0,'post');
                    end
                else
                    if timeNormFlag
                        results_perSub.(sideTmp).ContactPressure.(currentFnTable)(1:101,cnt) = interpft(outTmp.(fnTable{idxsT}),101); %create variable the first time
                    else
                        results_perSub.(sideTmp).ContactPressure.(currentFnTable)(1:numFrames,cnt) = padarray(outTmp.(fnTable{idxsT}),numFrames-length(outTmp.(fnTable{idxsT})),0,'post');
                    end
                end
            end

            % Increase side specific count
            if strcmp(sideTmp, 'r'); cntRight = cntRight + 1; end
            if strcmp(sideTmp, 'l'); cntLeft = cntLeft + 1; end

        end

        % Clean the tables with the DIRTY HACK
        for ss = 1 : 2
            fnTable = fieldnames(results_perSub.(sideS{ss}).ContactPressure);

            % Get columns count for side
            if strcmp(sideS{ss}, 'r'); cntColumn = cntRight; end % note thatthe cnt is already increased by +1.
            if strcmp(sideS{ss}, 'l'); cntColumn = cntLeft; end

            for i = 1 : length(fnTable)

                % Remove rows only containing nans - since this is only
                % applied to the non-time-normalized data I do not need it.
                % All array should have the same height of 500 cells.
                %results_perSub.(sideS{ss}).ContactPressure.(fnTable{i})(all(isnan(results_perSub.(sideS{ss}).ContactPressure.(fnTable{i})),2),:) = []; % rows

                % Remove columns which are only part of the "hacky" initialized array
                results_perSub.(sideS{ss}).ContactPressure.(fnTable{i})(:,cntColumn:end) = []; % columns
            end
        end
    end

    %% Collect all relevant data

    % Get nFrames over all trials
    standardSizeArray = 500; % set standard array size for padding when timeNorm is off.

    nFramesfilesForce = standardSizeArray; %getNumFrames(filesForce_dealed);
    nFramesfilesMuscleAct = standardSizeArray; %getNumFrames(filesMuscleAct_dealed);
    nFramesfilesMuscleForce = standardSizeArray; %getNumFrames(filesMuscleForce_dealed);
    nFramesfilesKinematicsComak = standardSizeArray; %getNumFrames(filesKinematicsComak_dealed);
    nFramesfilesInvKinematics = standardSizeArray; %getNumFrames(filesInvKinematics_dealed);
    nFramesfilesInverseDynamics = standardSizeArray; %getNumFrames(filesInverseDynamics_dealed);
    nFramesfilesForceReporter = standardSizeArray; %getNumFrames(filesForceReporter_dealed);
    nFramesfilesBodyKinematics = standardSizeArray; %getNumFrames(filesBodyKinematics_dealed);


    % Now read the data
    cntRight = 1; % site specific count to write data in correct columns
    cntLeft = 1;
    for i = 1 : length(filesForce_dealed)
        try
            % Read all files containing results
            [contactForce_data, contactForce_labels, contactForce_header] = read_opensim_mot(filesForce_dealed{i});
            [muscleAct_data, muscleAct_labels, muscleAct_header] = read_opensim_mot(filesMuscleAct_dealed{i});
            [muscleForce_data, muscleForce_labels, muscleForce_header] = read_opensim_mot(filesMuscleForce_dealed{i});
            [kinematicsComak_data, kinematicsComak_labels, kinematicsComak_header] = read_opensim_mot(filesKinematicsComak_dealed{i});
            [inverseKinematics_data, inverseKinematics_labels, inverseKinematics_header] = read_opensim_mot(filesInvKinematics_dealed{i});
            [inverseDyn_data, inverseDyn_labels, inverseDyn_header] = read_opensim_mot(filesInverseDynamics_dealed{i});
            [forceReporter_data, forceReporter_labels, forceReporter_header] = read_opensim_mot(filesForceReporter_dealed{i});
            [bodyKinematics_data, bodyKinematics_labels, bodyKinematics_header] = read_opensim_mot(filesBodyKinematics_dealed{i});

            tmpError = load(filesErrorIKLocs_dealed{i});
            IK_errorLocs = tmpError.errors;

            % Extract current file name of the loop and delete trailing and leading "_". Also get rid of prefix
            %trial_name_tmp = strip(erase(FileListForce_dealed(i).name(1:strfind(FileListForce_dealed(i).name ,'__ForceReporter')-1),prefix),'_');
            %name_tmp = trial_name_tmp(strfind(trial_name_tmp,condition):end); %get rid of prefix if prefix was not defined specifically
            stop_strIdx = strfind(filesForce_dealed{i} ,'jam')-2;
            tmp = strfind(filesForce_dealed{i}(1:stop_strIdx),'\');
            start_strIdx = tmp(end)+1;
            trial_name_tmp = strip(erase(filesForce_dealed{i}(start_strIdx:stop_strIdx),prefix),'_');
            name_tmp = trial_name_tmp(strfind(lower(trial_name_tmp),lower(condition)):end); %get rid of prefix if prefix was not defined specifically

            % Find in InputData trial names
            for k = 1 : length(FileNames_InputData)
                if contains(FileNames_InputData{k},name_tmp); trialNameInputData = FileNames_InputData{k}; end
            end

            % Add side tag to force labels which don�t have appended the side to their names
            contactForce_labels_side = {}; % initialize
            side_tmp = char(lower(InputData.(trialNameInputData).Side(1)));
            for s = 1 : length(contactForce_labels)
                if contains(contactForce_labels{s}(end-1:end), ['_',side_tmp])
                    contactForce_labels_side(s,1) = contactForce_labels(s);
                elseif ~contains(contactForce_labels{s}(end-1:end), ['_',side_tmp])
                    contactForce_labels_side(s,1) = strcat(contactForce_labels(s),'_', side_tmp);
                end
            end

            % Set side specific column-count
            if strcmp(side_tmp, 'r'); cnt = cntRight; end
            if strcmp(side_tmp, 'l'); cnt = cntLeft; end

            % Delete muscles in force reporte files as they do not show correct values.
            % I am only intersted in everything except the muscles!
            msl2exclude = {'addbrev', 'addlong', 'addmagProx', 'addmagMid', 'addmagDist', 'addmagIsch', ...
                'bflh', 'bfsh', 'edl', 'ehl', 'fdl', 'fhl', 'gaslat', 'gasmed', 'gem', 'glmax1', ...
                'glmax2', 'glmax3', 'glmed1', 'glmed2', 'glmed3', 'glmin1', 'glmin2', 'glmin3', 'grac', ...
                'iliacus', 'pect', 'perbrev', 'perlong', 'pertert', 'piri', 'psoas', 'quadfem', 'recfem', ...
                'sart', 'semimem', 'semiten', 'soleus', 'tfl', 'tibant', 'tibpost', 'vasint', 'vaslat', 'vasmed'};

            % Add side to muscles2exclude cell array
            msl2exclude = cellfun(@(c)[c '_' side_tmp],msl2exclude,'uni',false);

            % Create cleaned data
            col2exclude = not(ismember(contactForce_labels, msl2exclude));
            contactForce_data = contactForce_data(:,col2exclude);
            contactForce_labels_side = contactForce_labels_side(col2exclude);

            % Update header
            contactForce_header.nColumns = length(contactForce_data(col2exclude));

            % Contact Forces
            resultsAll_perTrial.(trial_name_tmp).dataForceData = contactForce_data;
            resultsAll_perTrial.(trial_name_tmp).labelsForceData = contactForce_labels_side;
            resultsAll_perTrial.(trial_name_tmp).headerForceData = contactForce_header;
            resultsAll_perTrial.(trial_name_tmp).ForceDataTable = cell2table(num2cell(contactForce_data),'VariableNames',contactForce_labels_side');

            % Muscle activation
            resultsAll_perTrial.(trial_name_tmp).dataMuscleAct = muscleAct_data;
            resultsAll_perTrial.(trial_name_tmp).labelsMuscleAct = muscleAct_labels;
            resultsAll_perTrial.(trial_name_tmp).headerMuscleAct = muscleAct_header;
            resultsAll_perTrial.(trial_name_tmp).MuscleActTable = cell2table(num2cell(muscleAct_data),'VariableNames',muscleAct_labels');

            % Muscle force
            resultsAll_perTrial.(trial_name_tmp).dataMuscleForce = muscleForce_data;
            resultsAll_perTrial.(trial_name_tmp).labelsMuscleForce = muscleForce_labels;
            resultsAll_perTrial.(trial_name_tmp).headerMuscleForce = muscleForce_header;
            resultsAll_perTrial.(trial_name_tmp).MuscleForceTable = cell2table(num2cell(muscleForce_data),'VariableNames',muscleForce_labels');

            % Kinematics Comak
            resultsAll_perTrial.(trial_name_tmp).dataKinematicsComak = kinematicsComak_data;
            resultsAll_perTrial.(trial_name_tmp).labelsKinematicsComak = kinematicsComak_labels;
            resultsAll_perTrial.(trial_name_tmp).headerKinematicsComak = kinematicsComak_header;
            resultsAll_perTrial.(trial_name_tmp).KinematicsComakTable = cell2table(num2cell(kinematicsComak_data),'VariableNames',kinematicsComak_labels');

            % Inverse Kinematics
            resultsAll_perTrial.(trial_name_tmp).dataInverseKinematics = inverseKinematics_data;
            resultsAll_perTrial.(trial_name_tmp).labelsInverseKinematics = inverseKinematics_labels;
            resultsAll_perTrial.(trial_name_tmp).headerInverseKinematics = inverseKinematics_header;
            resultsAll_perTrial.(trial_name_tmp).InverseKinematicsTable = cell2table(num2cell(inverseKinematics_data),'VariableNames',inverseKinematics_labels');

            % Inverse Dynamics
            resultsAll_perTrial.(trial_name_tmp).datainverseDyn = inverseDyn_data;
            resultsAll_perTrial.(trial_name_tmp).labelsinverseDyn = inverseDyn_labels;
            resultsAll_perTrial.(trial_name_tmp).headerinverseDyn = inverseDyn_header;
            resultsAll_perTrial.(trial_name_tmp).InverseDynamicsTable = cell2table(num2cell(inverseDyn_data),'VariableNames',inverseDyn_labels');

            % Force Reporter
            resultsAll_perTrial.(trial_name_tmp).dataforceReporter = forceReporter_data;
            resultsAll_perTrial.(trial_name_tmp).labelsforceReporter = forceReporter_labels;
            resultsAll_perTrial.(trial_name_tmp).headerforceReporter = forceReporter_header;
            resultsAll_perTrial.(trial_name_tmp).ForceReporterTable = cell2table(num2cell(forceReporter_data),'VariableNames',forceReporter_labels');

            % Body Kinematics
            resultsAll_perTrial.(trial_name_tmp).databodyKinematics = bodyKinematics_data;
            resultsAll_perTrial.(trial_name_tmp).labelsbodyKinematics = bodyKinematics_labels;
            resultsAll_perTrial.(trial_name_tmp).headerbodyKinematics = bodyKinematics_header;
            resultsAll_perTrial.(trial_name_tmp).BodyKinematicsTable = cell2table(num2cell(bodyKinematics_data),'VariableNames',bodyKinematics_labels');

            % IK error locs
            resultsAll_perTrial.(trial_name_tmp).IKerror = IK_errorLocs.IKerror;
            resultsAll_perTrial.(trial_name_tmp).ReserveActivation = IK_errorLocs.ReserveActivation;
            resultsAll_perTrial.(trial_name_tmp).ForceReserve = IK_errorLocs.ForceReserve;
            resultsAll_perTrial.(trial_name_tmp).IKerrorLocs = IK_errorLocs.IKerrorLocs;
            resultsAll_perTrial.(trial_name_tmp).ResidualForcesPelvis = IK_errorLocs.ResidualForcesPelvis;

            %% Write data to per subject struct

            % Write trial info
            if ~isfield(results_perSub.(side_tmp), 'trialName')
                results_perSub.(side_tmp).trialName{1,1} = name_tmp;
            else
                results_perSub.(side_tmp).trialName{1,cnt} = name_tmp;
            end

            % Collect ReserveActivation
            ReserveActivationVars = IK_errorLocs.ReserveActivation.Properties.VariableNames;
            for j = 1 : length(ReserveActivationVars)
                if~isfield(results_perSub.(side_tmp).ReserveActivation, (ReserveActivationVars{j}))
                    results_perSub.(side_tmp).ReserveActivation.(ReserveActivationVars{j})(:,1) = interpft(IK_errorLocs.ReserveActivation.(ReserveActivationVars{j}),101); %create variable the first time; For convenience I just always interpolate to 101.
                else
                    results_perSub.(side_tmp).ReserveActivation.(ReserveActivationVars{j})(:,cnt) = interpft(IK_errorLocs.ReserveActivation.(ReserveActivationVars{j}),101); % add data always to the right
                end
            end

            % Collect ForceReserve
            ForceReserveVars = IK_errorLocs.ForceReserve.Properties.VariableNames;
            for j = 1 : length(ForceReserveVars)
                if~isfield(results_perSub.(side_tmp).ForceReserve, (ForceReserveVars{j}))
                    results_perSub.(side_tmp).ForceReserve.(ForceReserveVars{j})(:,1) = interpft(IK_errorLocs.ForceReserve.(ForceReserveVars{j}),101); %create variable the first time; For convenience I just always interpolate to 101.
                else
                    results_perSub.(side_tmp).ForceReserve.(ForceReserveVars{j})(:,cnt) = interpft(IK_errorLocs.ForceReserve.(ForceReserveVars{j}),101); % add data always to the right
                end
            end

            % Collect ResidualForcesPelvis
            ResidualForcesPelvisVars = IK_errorLocs.ResidualForcesPelvis.Properties.VariableNames;
            for j = 1 : length(ResidualForcesPelvisVars)
                if~isfield(results_perSub.(side_tmp).ResidualForcesPelvis, (ResidualForcesPelvisVars{j}))
                    results_perSub.(side_tmp).ResidualForcesPelvis.(ResidualForcesPelvisVars{j})(:,1) = interpft(IK_errorLocs.ResidualForcesPelvis.(ResidualForcesPelvisVars{j}),101); %create variable the first time; For convenience I just always interpolate to 101.
                else
                    results_perSub.(side_tmp).ResidualForcesPelvis.(ResidualForcesPelvisVars{j})(:,cnt) = interpft(IK_errorLocs.ResidualForcesPelvis.(ResidualForcesPelvisVars{j}),101); % add data always to the right
                end
            end

            % Collect IK errors
            IKerrorsLocsMrksVars = IK_errorLocs.IKerrorLocs.Properties.VariableNames;
            for j = 1 : length(IKerrorsLocsMrksVars)
                if~isfield(results_perSub.(side_tmp).IKerrors, (IKerrorsLocsMrksVars{j}))
                    results_perSub.(side_tmp).IKerrors.(IKerrorsLocsMrksVars{j})(:,1) = interpft(IK_errorLocs.IKerrorLocs.(IKerrorsLocsMrksVars{j}),101); %create variable the first time; For convenience I just always interpolate to 101.
                else
                    results_perSub.(side_tmp).IKerrors.(IKerrorsLocsMrksVars{j})(:,cnt) = interpft(IK_errorLocs.IKerrorLocs.(IKerrorsLocsMrksVars{j}),101); % add data always to the right
                end
            end

            % Write Events: IC, ICi, ...
            eventVars = {'cTO','TO','IC','cIC','ICi'};

            for j = 1 : length(eventVars)
                if ~isfield(results_perSub.(side_tmp).Events, (eventVars{j}))
                    results_perSub.(side_tmp).Events.(eventVars{j})(1) = InputData.(trialNameInputData).(eventVars{j});
                else
                    results_perSub.(side_tmp).Events.(eventVars{j})(cnt) = InputData.(trialNameInputData).(eventVars{j});
                end
            end

            % Contact forces
            numFrames = size(contactForce_data,1); %height(contactForce_data); % get number of frames
            for j = 1:length(contactForce_labels_side)
                fn = char(strrep(contactForce_labels_side(j),'.','_'));
                if ~isfield(results_perSub.(side_tmp).ContactForces,fn)
                    if timeNormFlag
                        results_perSub.(side_tmp).ContactForces.(fn)(:,1) = interpft(contactForce_data(:,j),101); %create variable the first time
                    else
                        results_perSub.(side_tmp).ContactForces.(fn)(:,1) = padarray(contactForce_data(:,j),nFramesfilesForce-numFrames,0,'post'); % pad with nan if necessary
                    end
                else
                    if timeNormFlag
                        results_perSub.(side_tmp).ContactForces.(fn)(:,cnt) = interpft(contactForce_data(:,j),101); % add data always to the right
                    else
                        results_perSub.(side_tmp).ContactForces.(fn)(:,cnt) = padarray(contactForce_data(:,j),nFramesfilesForce-numFrames,0,'post'); % add data always to the right
                    end
                end
            end

            % Muscle Activations
            numFrames = size(muscleAct_data,1); %height(muscleAct_data); % get number of frames
            for j = 1:length(muscleAct_labels)
                fn = char(strrep(muscleAct_labels(j),'/','_'));
                if strcmp(fn(1), '_'); fn = fn(2:end); end % get rid of the first '_'
                if ~isfield(results_perSub.(side_tmp).MuscleActivations,fn)
                    if timeNormFlag
                        results_perSub.(side_tmp).MuscleActivations.(fn)(:,1) = interpft(muscleAct_data(:,j),101);
                    else
                        results_perSub.(side_tmp).MuscleActivations.(fn)(:,1) = padarray(muscleAct_data(:,j),nFramesfilesMuscleAct-numFrames,0,'post');
                    end
                else
                    if timeNormFlag
                        results_perSub.(side_tmp).MuscleActivations.(fn)(:,cnt) = interpft(muscleAct_data(:,j),101); % add data always to the right
                    else
                        results_perSub.(side_tmp).MuscleActivations.(fn)(:,cnt) = padarray(muscleAct_data(:,j),nFramesfilesMuscleAct-numFrames,0,'post'); % add data always to the right
                    end
                end
            end

            % Muscle Forces
            numFrames = size(muscleForce_data,1); % height(muscleForce_data); % get number of frames
            for j = 1:length(muscleForce_labels)
                fn = char(strrep(muscleForce_labels(j),'/','_'));
                if strcmp(fn(1), '_'); fn = fn(2:end); end % get rid of the first '_'
                if ~isfield(results_perSub.(side_tmp).MuscleForces,fn)
                    if timeNormFlag
                        results_perSub.(side_tmp).MuscleForces.(fn)(:,1) = interpft(muscleForce_data(:,j),101); %create variable sthe first time
                    else
                        results_perSub.(side_tmp).MuscleForces.(fn)(:,1) = padarray(muscleForce_data(:,j),nFramesfilesMuscleForce-numFrames,0,'post'); %create variable sthe first time
                    end
                else
                    if timeNormFlag
                        results_perSub.(side_tmp).MuscleForces.(fn)(:,cnt) = interpft(muscleForce_data(:,j),101); % add data always to the right
                    else
                        results_perSub.(side_tmp).MuscleForces.(fn)(:,cnt) = padarray(muscleForce_data(:,j),nFramesfilesMuscleForce-numFrames,0,'post'); % add data always to the right
                    end
                end
            end

            % Kinematics Comak
            numFrames = size(kinematicsComak_data,1); % height(kinematicsComak_data); % get number of frames
            for j = 1:length(kinematicsComak_labels)
                fn = char(kinematicsComak_labels(j));

                % Because I get values for both sides and I want to know which side
                % is the one analzyed (with comak) I had to use these lables. This
                % is only necessary for kinematics and inverse dynamics
                if side_tmp == 'r'
                    if strcmp(fn(end-1:end),'_r'); fn = strcat(fn,'_ipsilateral'); end
                    if strcmp(fn(end-1:end),'_l'); fn = strcat(fn,'_contralateral'); end
                elseif side_tmp == 'l'
                    if strcmp(fn(end-1:end),'_r'); fn = strcat(fn,'_contralateral'); end
                    if strcmp(fn(end-1:end),'_l'); fn = strcat(fn,'_ipsilateral'); end
                end

                if ~isfield(results_perSub.(side_tmp).KinematicsComak,fn)
                    if timeNormFlag
                        results_perSub.(side_tmp).KinematicsComak.(fn)(:,1) = interpft(kinematicsComak_data(:,j),101); %create variable sthe first time
                    else
                        results_perSub.(side_tmp).KinematicsComak.(fn)(:,1) = padarray(kinematicsComak_data(:,j),nFramesfilesKinematicsComak-numFrames,0,'post'); %create variable sthe first time
                    end
                else
                    if timeNormFlag
                        results_perSub.(side_tmp).KinematicsComak.(fn)(:,cnt) = interpft(kinematicsComak_data(:,j),101); % add data always to the right
                    else
                        results_perSub.(side_tmp).KinematicsComak.(fn)(:,cnt) = padarray(kinematicsComak_data(:,j),nFramesfilesKinematicsComak-numFrames,0,'post'); % add data always to the right
                    end
                end
            end

            % Inverse Kinematics
            numFrames = size(inverseKinematics_data,1); % height(inverseKinematics_data); % get number of frames
            for j = 1:length(inverseKinematics_labels)
                fn = char(inverseKinematics_labels(j));

                % Because I get values for both sides and I want to know which side
                % is the one analzyed (with comak) I had to use these lables. This
                % is only necessary for kinematics and inverse dynamics
                if side_tmp == 'r'
                    if strcmp(fn(end-1:end),'_r'); fn = strcat(fn,'_ipsilateral'); end
                    if strcmp(fn(end-1:end),'_l'); fn = strcat(fn,'_contralateral'); end
                elseif side_tmp == 'l'
                    if strcmp(fn(end-1:end),'_r'); fn = strcat(fn,'_contralateral'); end
                    if strcmp(fn(end-1:end),'_l'); fn = strcat(fn,'_ipsilateral'); end
                end

                if ~isfield(results_perSub.(side_tmp).InverseKinematics,fn)
                    if timeNormFlag
                        results_perSub.(side_tmp).InverseKinematics.(fn)(:,1) = interpft(inverseKinematics_data(:,j),101); %create variable the first time
                    else
                        results_perSub.(side_tmp).InverseKinematics.(fn)(:,1) = padarray(inverseKinematics_data(:,j),nFramesfilesInvKinematics-numFrames,0,'post'); %create variable the first time
                    end
                else
                    if timeNormFlag
                        results_perSub.(side_tmp).InverseKinematics.(fn)(:,cnt) = interpft(inverseKinematics_data(:,j),101); % add data always to the right
                    else
                        results_perSub.(side_tmp).InverseKinematics.(fn)(:,cnt) = padarray(inverseKinematics_data(:,j),nFramesfilesInvKinematics-numFrames,0,'post'); % add data always to the right
                    end
                end
            end

            % Inverse Dynamics
            numFrames = size(inverseDyn_data,1); % height(inverseDyn_data); % get number of frames
            for j = 1:length(inverseDyn_labels)
                fn = char(inverseDyn_labels(j));

                % Because I get values for both sides and I want to know which side
                % is the one analzyed (with comak) I had to use these lables. This
                % is only necessary for kinematics and inverse dynamics
                % Note this syntax is different to kinematics comak!
                if side_tmp == 'r'
                    if contains(fn,'_r_'); fn = strcat(fn,'_ipsilateral'); end
                    if contains(fn,'_l_'); fn = strcat(fn,'_contralateral'); end
                elseif side_tmp == 'l'
                    if contains(fn,'_r_'); fn = strcat(fn,'_contralateral'); end
                    if contains(fn,'_l_'); fn = strcat(fn,'_ipsilateral'); end
                end

                if ~isfield(results_perSub.(side_tmp).InverseDynamics,fn)
                    if timeNormFlag
                        results_perSub.(side_tmp).InverseDynamics.(fn)(:,1) = interpft(inverseDyn_data(:,j),101); %create variable sthe first time
                    else
                        results_perSub.(side_tmp).InverseDynamics.(fn)(:,1) = padarray(inverseDyn_data(:,j),nFramesfilesInverseDynamics-numFrames,0,'post'); %create variable sthe first time
                    end
                else
                    if timeNormFlag
                        results_perSub.(side_tmp).InverseDynamics.(fn)(:,cnt) = interpft(inverseDyn_data(:,j),101); % add data always to the right
                    else
                        results_perSub.(side_tmp).InverseDynamics.(fn)(:,cnt) = padarray(inverseDyn_data(:,j),nFramesfilesInverseDynamics-numFrames,0,'post'); % add data always to the right
                    end
                end
            end

            % Force Reporter (GRFs)
            numFrames = size(forceReporter_data,1);
            idxSide = find(contains(forceReporter_labels, strcat('_', side_tmp, '_', 'FP'))); % get cells populating the force plate data of the side of interest

            % Init
            FPlabel2use = [];
            forceReporter_labels_GRF = [];
            forceReporter_data_GRF = [];

            if isempty(idxSide)
                % do nothing 4 now
            else
                % Check if one or more FPs are listed, one FP should have 9 variables 3xforce 3xcop 3xtorque
                if length(idxSide) == 9 % here I only assume one FP
                    forceReporter_data_GRF = forceReporter_data(:,idxSide);
                    forceReporter_labels_GRF = forceReporter_labels(idxSide);
                    FPlabel2use = forceReporter_labels_GRF{1}(end-5:end-3);

                else % Here we have several FPs, only one is the correct one
                    forceReporter_labels_tmp = forceReporter_labels(idxSide);
                    forceReporter_data_tmp = forceReporter_data(:,idxSide);

                    % Get all vars for the vertical force
                    idxFy = contains(forceReporter_labels_tmp, 'Fy');
                    forceReporter_labels_Fy = forceReporter_labels_tmp(idxFy);
                    forceReporter_data_Fy = forceReporter_data_tmp(:,idxFy);

                    % Here I assume that the FP with the greater avg Force is the correct one
                    [~, idxFP] = max(mean(abs(forceReporter_data_Fy),1));
                    FPlabel2use = forceReporter_labels_Fy{idxFP}(end-5:end-3);

                    % Get labels for the correct FP
                    idxFPsignals = find(contains(forceReporter_labels_tmp, FPlabel2use));
                    forceReporter_labels_GRF = forceReporter_labels_tmp(idxFPsignals);

                    % Reduce the data to match the labels array
                    forceReporter_data_GRF = forceReporter_data_tmp(:,idxFPsignals);
                end

                for j = 1:length(forceReporter_labels_GRF)
                    fn = forceReporter_labels_GRF{j}(end-1:end); % extract meaningful var name

                    if ~isfield(results_perSub.(side_tmp).GRFs,fn)
                        if timeNormFlag
                            results_perSub.(side_tmp).GRFs.(fn)(:,1) = interpft(forceReporter_data_GRF(:,j),101); %create variables the first time
                        else
                            results_perSub.(side_tmp).GRFs.(fn)(:,1) = padarray(forceReporter_data_GRF(:,j),nFramesfilesForceReporter-numFrames,0,'post'); %create variable sthe first time
                        end
                        % Collect info which FP was used
                        results_perSub.(side_tmp).GRFs.FPused{1} = FPlabel2use;
                    else
                        if timeNormFlag
                            results_perSub.(side_tmp).GRFs.(fn)(:,cnt) = interpft(forceReporter_data_GRF(:,j),101); % add data always to the right
                        else
                            results_perSub.(side_tmp).GRFs.(fn)(:,cnt) = padarray(forceReporter_data_GRF(:,j),nFramesfilesForceReporter-numFrames,0,'post'); % add data always to the right
                        end
                        % Collect info which FP was used
                        results_perSub.(side_tmp).GRFs.FPused{cnt} = FPlabel2use;
                    end
                end
            end

            % Body Kinematics
            numFrames = size(bodyKinematics_data,1);
            for j = 1:length(bodyKinematics_labels)
                fn = char(bodyKinematics_labels(j));

                % Because I get values for both sides and I want to know which side
                % is the one analzyed (with comak) I had to use these lables. This
                % is only necessary for kinematics and inverse dynamics
                % Note this syntax is different to kinematics comak!
                if side_tmp == 'r'
                    if contains(fn,'_r_'); fn = strcat(fn,'_ipsilateral'); end
                    if contains(fn,'_l_'); fn = strcat(fn,'_contralateral'); end
                elseif side_tmp == 'l'
                    if contains(fn,'_r_'); fn = strcat(fn,'_contralateral'); end
                    if contains(fn,'_l_'); fn = strcat(fn,'_ipsilateral'); end
                end

                if ~isfield(results_perSub.(side_tmp).BodyKinematics,fn)
                    if timeNormFlag
                        results_perSub.(side_tmp).BodyKinematics.(fn)(:,1) = interpft(bodyKinematics_data(:,j),101); %create variable sthe first time
                    else
                        results_perSub.(side_tmp).BodyKinematics.(fn)(:,1) = padarray(bodyKinematics_data(:,j),nFramesfilesBodyKinematics-numFrames,0,'post'); %create variable sthe first time
                    end
                else
                    if timeNormFlag
                        results_perSub.(side_tmp).BodyKinematics.(fn)(:,cnt) = interpft(bodyKinematics_data(:,j),101); % add data always to the right
                    else
                        results_perSub.(side_tmp).BodyKinematics.(fn)(:,cnt) = padarray(bodyKinematics_data(:,j),nFramesfilesBodyKinematics-numFrames,0,'post'); % add data always to the right
                    end
                end
            end

            % Increase side specific count
            if strcmp(side_tmp, 'r'); cntRight = cntRight + 1; end
            if strcmp(side_tmp, 'l'); cntLeft = cntLeft + 1; end

        catch
            % Catch any error which occured in the above section, notify
            % user, and delete relevant output from files to save.

            % Notify user
            warning(strcat('>>>>> An error occured while processing file <', trial_name_tmp,'>. File was skipped!')) ;

            % Delete current node from resultsAll_perTrial
            if isfield(resultsAll_perTrial, trial_name_tmp) % check if some data were written to struct alraedy
                resultsAll_perTrial = rmfield(resultsAll_perTrial, trial_name_tmp);
            end

            % Delete from results_perSub
            if strcmp(results_perSub.(side_tmp).trialName{end}, trial_name_tmp)  % check if some data were written to struct alraedy, event  data is the first

                fnTmp1 = fieldnames(results_perSub.(side_tmp)); % Get fieldnames
                for i_fnLv1 = 1 : length(fnTmp1) % fieldnames Kinematics, Kinetics, Force

                    fnTmp2 = fieldnames(results_perSub.(side_tmp).(fnTmp1{i_fnLv1}));
                    for i_fnLv2 = 1 : length(fnTmp2) % fieldnames vars

                        if any(ismember(results_perSub.(side_tmp).trialName, trial_name_tmp))
                            % index from event data
                            idx2del = find(ismember(results_perSub.(side_tmp).trialName, trial_name_tmp));
                            % delte that column
                            results_perSub.(side_tmp).(fnTmp1{i_fnLv1}).(fnTmp2{i_fnLv2})(:, idx2del) = [];
                        end
                    end
                end
            end
        end
    end

    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % PLOTTING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Plot GRF
    hfig_GRF = figure;
    set(hfig_GRF,'units','centimeters','position',[0,0,30,10]);
    orient(hfig_GRF,'landscape');
    sgtitle(strcat('Results ForceReporter (GRFs only):',{' '}, prefix,{' - '}, condition,{' - '}, strrep(subjectName,'_',{' '}), '; R = red | L = blue'),'FontWeight','bold');

    % GRF vars 2 plot
    GRFVars2plot = {'Fx', 'Fy', 'Fz'};

    for i = 1:length(GRFVars2plot)

        % Plot data
        subaxis(1,3,i,'SpacingVert',0.02,'MR',0.1)
        label_r = (strrep(GRFVars2plot{i},'#', 'r'));
        label_l = (strrep(GRFVars2plot{i},'#', 'l'));

        dat_r = [];
        dat_l = [];
        % Both
        if isfield(results_perSub.('r').GRFs,label_r) && isfield(results_perSub.('l').GRFs,label_l)
            dat_r = results_perSub.('r').GRFs.(label_r);
            dat_l = results_perSub.('l').GRFs.(label_l);
            hold on
            plot(dat_r,'LineWidth',line_width, 'Color', 'r');
            plot(dat_l,'LineWidth',line_width, 'Color', 'b', 'LineStyle', '--');
            s_tmp = '(L/R)';

            % Only right
        elseif isfield(results_perSub.('r').GRFs,label_r) && ~isfield(results_perSub.('l').GRFs,label_l)
            dat_r = results_perSub.('r').GRFs.(label_r);
            dat_l = nan(size(dat_r));
            hold on
            plot(dat_r,'LineWidth',line_width, 'Color', 'r');
            s_tmp = '(R)';

            % Only left
        elseif isfield(results_perSub.('l').GRFs,label_l) && ~isfield(results_perSub.('r').GRFs,label_r)
            dat_l = results_perSub.('l').GRFs.(label_l);
            dat_r = nan(size(dat_l));
            hold on
            plot(dat_l,'LineWidth',line_width, 'Color', 'b');
            s_tmp = '(L)';

        end

        box on;
        %title(strrep(strrep(GRFVars2plot{i}, '_',' '),'#',''));
        ylabel(strcat(GRFVars2plot{i}, ' [Newton]'));

        % Do this only if current force plate was used
        if ~isempty(dat_r)
            numFrames = size(dat_r,1); % get number of frames, both l/r will be always created, see above
            xlim([0 numFrames]);
        end

        xlabel('Frames or time (%)');
    end

    %% Plot kinematics from COAMK
    hfig_ComakKinem = figure;
    set(hfig_ComakKinem,'units','centimeters','position',[0,0,29,21]);
    orient(hfig_ComakKinem,'landscape');
    sgtitle(strcat('Results Report (COMAK-Kinematics):',{' '}, prefix,{' - '}, condition,{' - '}, strrep(subjectName,'_',{' '}), '; R = red | L = blue'),'FontWeight','bold');

    kinemVars2plot = {...
        'pelvis_tilt','pelvis_list','pelvis_rot', ...
        'hip_flex_#_ipsilateral' ,'hip_add_#_ipsilateral' ,'hip_rot_#_ipsilateral' , ...
        'pf_flex_#_ipsilateral' ,'pf_rot_#_ipsilateral' ,'pf_tilt_#_ipsilateral', ...
        'knee_flex_#_ipsilateral', 'knee_add_#_ipsilateral' ,'knee_rot_#_ipsilateral' , ...
        'ankle_flex_#_ipsilateral' ,'subt_angle_#_ipsilateral'};

    for i = 1:length(kinemVars2plot)

        % Plot data
        subaxis(5,3,i,'SpacingVert',0.02,'MR',0.1)
        label_r = (strrep(kinemVars2plot{i},'#', 'r'));
        label_l = (strrep(kinemVars2plot{i},'#', 'l'));

        % Both
        if isfield(results_perSub.('r').KinematicsComak,label_r) && isfield(results_perSub.('l').KinematicsComak,label_l)
            dat_r = results_perSub.('r').KinematicsComak.(label_r);
            dat_l = results_perSub.('l').KinematicsComak.(label_l);
            hold on
            plot(dat_r,'LineWidth',line_width, 'Color', 'r');
            plot(dat_l,'LineWidth',line_width, 'Color', 'b', 'LineStyle', '--');
            s_tmp = '(L/R)';

            cIC_r = mean((results_perSub.('r').Events.cIC - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cTO_r = mean((results_perSub.('r').Events.cTO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            TO_r =  mean((results_perSub.('r').Events.TO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cIC_l = mean((results_perSub.('l').Events.cIC - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            cTO_l = mean((results_perSub.('l').Events.cTO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            TO_l =  mean((results_perSub.('l').Events.TO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time

            cIC = mean([cIC_r, cIC_l]);
            cTO = mean([cTO_r, cTO_l]);
            TO = mean([TO_r, TO_l]);

            % Only right
        elseif isfield(results_perSub.('r').KinematicsComak,label_r) && ~isfield(results_perSub.('l').KinematicsComak,label_l)
            dat_r = results_perSub.('r').KinematicsComak.(label_r);
            dat_l = nan(size(dat_r));
            hold on
            plot(dat_r,'LineWidth',line_width, 'Color', 'r');
            s_tmp = '(R)';
            cIC = mean((results_perSub.('r').Events.cIC - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cTO = mean((results_perSub.('r').Events.cTO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            TO =  mean((results_perSub.('r').Events.TO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time

            % Only left
        elseif isfield(results_perSub.('l').KinematicsComak,label_l) && ~isfield(results_perSub.('r').KinematicsComak,label_r)
            dat_l = results_perSub.('l').KinematicsComak.(label_l);
            dat_r = nan(size(dat_l));
            hold on
            plot(dat_l,'LineWidth',line_width, 'Color', 'b');
            s_tmp = '(L)';

            cIC = mean((results_perSub.('l').Events.cIC - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            cTO = mean((results_perSub.('l').Events.cTO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            TO =  mean((results_perSub.('l').Events.TO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
        end

        box on;
        title(strrep(strrep(kinemVars2plot{i}, '_',' '),'#',''));
        ylabel('degrees')
        % Add cTO, TO
        hold on;
        y_min = min(min([dat_r dat_l]));
        y_max = max(max([dat_r dat_l]));
        line([cTO cTO],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        line([TO TO],[y_min y_max],'Color','k', 'LineStyle', '-', 'LineWidth', 0.5);
        line([cIC cIC],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);

        numFrames = size(dat_r,1); % get number of frames
        xlim([0 numFrames]);
        if y_max > y_min
            ylim([y_min y_max]);
        end

        if i < 12
            set(gca,'XTickLabel',[]);
        else
            xlabel('Frames or time (%)');
        end
    end

    %% Plot kinematics
    hfig_Kinem = figure;
    set(hfig_Kinem,'units','centimeters','position',[0,0,29,21]);
    orient(hfig_Kinem,'landscape');
    sgtitle(strcat('Results Report (Kinematics):',{' '}, prefix,{' - '}, condition,{' - '}, strrep(subjectName,'_',{' '}), '; R = red | L = blue'),'FontWeight','bold');

    kinemVars2plot = {...
        'pelvis_tilt','pelvis_list','pelvis_rot', ...
        'hip_flex_#_ipsilateral' ,'hip_add_#_ipsilateral' ,'hip_rot_#_ipsilateral' , ...
        'pf_flex_#_ipsilateral' ,'pf_rot_#_ipsilateral' ,'pf_tilt_#_ipsilateral', ...
        'knee_flex_#_ipsilateral', 'knee_add_#_ipsilateral' ,'knee_rot_#_ipsilateral' , ...
        'ankle_flex_#_ipsilateral' ,'subt_angle_#_ipsilateral'};

    for i = 1:length(kinemVars2plot)

        % Plot data
        subaxis(5,3,i,'SpacingVert',0.02,'MR',0.1)
        label_r = (strrep(kinemVars2plot{i},'#', 'r'));
        label_l = (strrep(kinemVars2plot{i},'#', 'l'));

        % Both
        if isfield(results_perSub.('r').InverseKinematics,label_r) && isfield(results_perSub.('l').InverseKinematics,label_l)
            dat_r = results_perSub.('r').InverseKinematics.(label_r);
            dat_l = results_perSub.('l').InverseKinematics.(label_l);
            hold on
            plot(dat_r,'LineWidth',line_width, 'Color', 'r');
            plot(dat_l,'LineWidth',line_width, 'Color', 'b', 'LineStyle', '--');
            s_tmp = '(L/R)';

            cIC_r = mean((results_perSub.('r').Events.cIC - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cTO_r = mean((results_perSub.('r').Events.cTO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            TO_r =  mean((results_perSub.('r').Events.TO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cIC_l = mean((results_perSub.('l').Events.cIC - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            cTO_l = mean((results_perSub.('l').Events.cTO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            TO_l =  mean((results_perSub.('l').Events.TO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time

            cIC = mean([cIC_r, cIC_l]);
            cTO = mean([cTO_r, cTO_l]);
            TO = mean([TO_r, TO_l]);

            % Only right
        elseif isfield(results_perSub.('r').InverseKinematics,label_r) && ~isfield(results_perSub.('l').InverseKinematics,label_l)
            dat_r = results_perSub.('r').InverseKinematics.(label_r);
            dat_l = nan(size(dat_r));
            hold on
            plot(dat_r,'LineWidth',line_width, 'Color', 'r');
            s_tmp = '(R)';
            cIC = mean((results_perSub.('r').Events.cIC - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cTO = mean((results_perSub.('r').Events.cTO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            TO =  mean((results_perSub.('r').Events.TO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time

            % Only left
        elseif isfield(results_perSub.('l').InverseKinematics,label_l) && ~isfield(results_perSub.('r').InverseKinematics,label_r)
            dat_l = results_perSub.('l').InverseKinematics.(label_l);
            dat_r = nan(size(dat_l));
            hold on
            plot(dat_l,'LineWidth',line_width, 'Color', 'b');
            s_tmp = '(L)';

            cIC = mean((results_perSub.('l').Events.cIC - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            cTO = mean((results_perSub.('l').Events.cTO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            TO =  mean((results_perSub.('l').Events.TO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
        end

        box on;
        title(strrep(strrep(kinemVars2plot{i}, '_',' '),'#',''));
        ylabel('degrees')
        % Add cTO, TO
        hold on;
        y_min = min(min([dat_r dat_l]));
        y_max = max(max([dat_r dat_l]));
        line([cTO cTO],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        line([TO TO],[y_min y_max],'Color','k', 'LineStyle', '-', 'LineWidth', 0.5);
        line([cIC cIC],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);

        numFrames = size(dat_r,1); % get number of frames
        xlim([0 numFrames]);
        if y_max > y_min
            ylim([y_min y_max]);
        end

        if i < 12
            set(gca,'XTickLabel',[]);
        else
            xlabel('Frames or time (%)');
        end
    end

    %% Plot Moments
    hfig_InvDyn = figure;
    set(hfig_InvDyn,'units','centimeters','position',[0,0,29,21]);
    orient(hfig_InvDyn,'landscape');
    sgtitle(strcat('Results Report (Moments):',{' '}, prefix,{' - '}, condition,{' - '}, strrep(subjectName,'_',{' '}), '; R = red | L = blue'),'FontWeight','bold');

    % Note the '#' place holder in the names!
    InvDynVars2plot = { ...
        'pelvis_tilt_moment','pelvis_list_moment','pelvis_rot_moment',...
        'pelvis_tx_force','pelvis_ty_force','pelvis_tz_force', ...
        'hip_flex_#_moment_ipsilateral' ,'hip_add_#_moment_ipsilateral' ,'hip_rot_#_moment_ipsilateral' ,...
        'pf_flex_#_moment_ipsilateral' ,'pf_rot_#_moment_ipsilateral' ,'pf_tilt_#_moment_ipsilateral', ...
        'pf_tx_#_force_ipsilateral' ,'pf_ty_#_force_ipsilateral' ,'pf_tz_#_force_ipsilateral' , ...
        'knee_flex_#_moment_ipsilateral', 'knee_add_#_moment_ipsilateral' ,'knee_rot_#_moment_ipsilateral', ...
        'knee_tx_#_force_ipsilateral','knee_ty_#_force_ipsilateral', 'knee_tz_#_force_ipsilateral', ...
        'ankle_flex_#_moment_ipsilateral','subt_angle_#_moment_ipsilateral', 'mtp_angle_#_moment_ipsilateral'};

    % 'pelvis_tilt_moment','pelvis_list_moment','pelvis_rot_moment','pelvis_tx_force','pelvis_ty_force','pelvis_tz_force', ...
    %     'hip_flex_r_moment_ipsilateral' ,'hip_add_r_moment_ipsilateral' ,'hip_rot_r_moment_ipsilateral' ,'hip_flex_l_moment_contralateral', ...
    %     'hip_add_l_moment_contralateral' ,'hip_rot_l_moment_contralateral' ,'lumbar_ext_moment' ,'lumbar_latbend_moment',...
    %     'lumbar_rot_moment' ,'pf_l_r3_moment_contralateral' ,'pf_l_tx_force_contralateral' ,'pf_l_ty_force_contralateral', ...
    %     'knee_flex_l_force_contralateral' ,'neck_ext_moment','neck_latbend_moment' ,'neck_rot_moment','arm_add_r_moment_ipsilateral', ...
    %     'arm_flex_r_moment_ipsilateral' ,'arm_rot_r_moment_ipsilateral' ,'arm_add_l_moment_contralateral' ,'arm_flex_l_moment_contralateral', ...
    %     'arm_rot_l_moment_contralateral' ,'pf_flex_r_moment_ipsilateral' ,'pf_rot_r_moment_ipsilateral' ,'pf_tilt_r_moment_ipsilateral', ...
    %     'pf_tx_r_force_ipsilateral' ,'pf_ty_r_force_ipsilateral' ,'pf_tz_r_force_ipsilateral' ,'knee_flex_r_moment_ipsilateral', ...
    %     'knee_add_r_moment_ipsilateral' ,'knee_rot_r_moment_ipsilateral' ,'knee_tx_r_force_ipsilateral','knee_ty_r_force_ipsilateral', ...
    %     'knee_tz_r_force_ipsilateral' ,'ankle_flex_l_moment_contralateral' ,'elbow_flex_r_moment_ipsilateral', ...
    %     'elbow_flex_l_moment_contralateral' ,'subt_angle_l_moment_contralateral' ,'pro_sup_r_moment_ipsilateral', ...
    %     'pro_sup_l_moment_contralateral' ,'ankle_flex_r_moment_ipsilateral' ,'mtp_angle_l_moment_contralateral', ...
    %     'wrist_flex_r_moment_ipsilateral' ,'wrist_flex_l_moment_contralateral' ,'subt_angle_r_moment_ipsilateral', ...
    %     'mtp_angle_r_moment_ipsilateral'

    for i = 1:length(InvDynVars2plot)

        % Plot data
        subaxis(8,3,i,'SpacingVert',0.02,'MR',0.1)
        label_r = (strrep(InvDynVars2plot{i},'#', 'r'));
        label_l = (strrep(InvDynVars2plot{i},'#', 'l'));

        % Both
        if isfield(results_perSub.('r').InverseDynamics,label_r) && isfield(results_perSub.('l').InverseDynamics,label_l)
            dat_r = results_perSub.('r').InverseDynamics.(label_r);
            dat_l = results_perSub.('l').InverseDynamics.(label_l);
            hold on
            hre = plot(dat_r,'LineWidth',line_width, 'Color', 'r');
            hle = plot(dat_l,'LineWidth',line_width, 'Color', 'b', 'LineStyle', '--');
            s_tmp = '(L/R)';

            cIC_r = mean((results_perSub.('r').Events.cIC - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cTO_r = mean((results_perSub.('r').Events.cTO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            TO_r =  mean((results_perSub.('r').Events.TO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cIC_l = mean((results_perSub.('l').Events.cIC - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            cTO_l = mean((results_perSub.('l').Events.cTO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            TO_l =  mean((results_perSub.('l').Events.TO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time

            cIC = mean([cIC_r, cIC_l]);
            cTO = mean([cTO_r, cTO_l]);
            TO = mean([TO_r, TO_l]);

            % Only right
        elseif isfield(results_perSub.('r').InverseDynamics,label_r) && ~isfield(results_perSub.('l').InverseDynamics,label_l)
            dat_r = results_perSub.('r').InverseDynamics.(label_r);
            dat_l = nan(size(dat_r));
            hold on
            hre = plot(dat_r,'LineWidth',line_width, 'Color', 'r');
            s_tmp = '(R)';
            cIC = mean((results_perSub.('r').Events.cIC - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cTO = mean((results_perSub.('r').Events.cTO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            TO =  mean((results_perSub.('r').Events.TO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time

            % Only left
        elseif isfield(results_perSub.('l').InverseDynamics,label_l) && ~isfield(results_perSub.('r').InverseDynamics,label_r)
            dat_l = results_perSub.('l').InverseDynamics.(label_l);
            dat_r = nan(size(dat_l));
            hold on
            hle = plot(dat_l,'LineWidth',line_width, 'Color', 'b');
            s_tmp = '(L)';

            cIC = mean((results_perSub.('l').Events.cIC - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            cTO = mean((results_perSub.('l').Events.cTO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            TO =  mean((results_perSub.('l').Events.TO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
        end

        box on;
        title(strrep(strrep(InvDynVars2plot{i}, '_',' '),'#',''));
        ylabel('Nm')
        % Add cTO, TO
        hold on;
        y_min = min(min([dat_r dat_l]));
        y_max = max(max([dat_r dat_l]));
        line([cTO cTO],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        line([TO TO],[y_min y_max],'Color','k', 'LineStyle', '-', 'LineWidth', 0.5);
        line([cIC cIC],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);

        numFrames = size(dat_r,1); % get number of frames
        xlim([0 numFrames]);
        if y_max > y_min
            ylim([y_min y_max]);
        end

        if i < 22
            set(gca,'XTickLabel',[]);
        else
            xlabel('Frames or time (%)');
        end
    end

    %% Plot Muscle Forces
    hfig_MF = figure;
    set(hfig_MF,'units','centimeters','position',[0,0,29,21]);
    orient(hfig_MF,'landscape');
    sgtitle(strcat('Results Report (Muscle Forces):',{' '}, prefix,{' - '}, condition,{' - '}, strrep(subjectName,'_',{' '}), '; R = red | L = blue'),'FontWeight','bold');
    msls_names = strrep(msls,'_', ' ');

    for i = 1:length(msls)

        % Plot data
        subaxis(8,6,i,'SpacingVert',0.02,'MR',0.1)
        label_r = (strcat('forceset_', msls{i},'r'));
        label_l = (strcat('forceset_', msls{i},'l'));

        % Both
        if isfield(results_perSub.('r').MuscleForces,label_r) && isfield(results_perSub.('l').MuscleForces,label_l)
            dat_r = results_perSub.('r').MuscleForces.(label_r);
            dat_l = results_perSub.('l').MuscleForces.(label_l);
            hold on
            plot(dat_r,'LineWidth',line_width, 'Color', 'r');
            plot(dat_l,'LineWidth',line_width, 'Color', 'b', 'LineStyle', '--');
            s_tmp = '(L/R)';

            cIC_r = mean((results_perSub.('r').Events.cIC - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cTO_r = mean((results_perSub.('r').Events.cTO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            TO_r =  mean((results_perSub.('r').Events.TO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cIC_l = mean((results_perSub.('l').Events.cIC - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            cTO_l = mean((results_perSub.('l').Events.cTO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            TO_l =  mean((results_perSub.('l').Events.TO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time

            cIC = mean([cIC_r, cIC_l]);
            cTO = mean([cTO_r, cTO_l]);
            TO = mean([TO_r, TO_l]);

            % Only right
        elseif isfield(results_perSub.('r').MuscleForces,label_r) && ~isfield(results_perSub.('l').MuscleForces,label_l)
            dat_r = results_perSub.('r').MuscleForces.(label_r);
            dat_l = nan(size(dat_r));
            hold on
            plot(dat_r,'LineWidth',line_width, 'Color', 'r');
            s_tmp = '(R)';
            cIC = mean((results_perSub.('r').Events.cIC - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cTO = mean((results_perSub.('r').Events.cTO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            TO =  mean((results_perSub.('r').Events.TO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time

            % Only left
        elseif isfield(results_perSub.('l').MuscleForces,label_l) && ~isfield(results_perSub.('r').MuscleForces,label_r)
            dat_l = results_perSub.('l').MuscleForces.(label_l);
            dat_r = nan(size(dat_l));
            hold on
            plot(dat_l,'LineWidth',line_width, 'Color', 'b');
            s_tmp = '(L)';

            cIC = mean((results_perSub.('l').Events.cIC - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            cTO = mean((results_perSub.('l').Events.cTO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            TO =  mean((results_perSub.('l').Events.TO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
        end

        box on;
        ylabel(msls_names{i});

        % Add cTO, TO
        hold on;
        y_min = min(min([dat_r dat_l]));
        y_max = max(max([dat_r dat_l]));
        line([cTO cTO],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        line([TO TO],[y_min y_max],'Color','k', 'LineStyle', '-', 'LineWidth', 0.5);
        line([cIC cIC],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);

        numFrames = size(dat_r,1); % get number of frames
        xlim([0 numFrames]);
        ylim([y_min y_max]);

        if i < 39
            set(gca,'XTickLabel',[]);
        else
            xlabel('Frames or time (%)');
        end
    end

    %% Plot Muscle Activations
    hfig_MA = figure;
    set(hfig_MA,'units','centimeters','position',[0,0,29,21]);
    orient(hfig_MA,'landscape');
    sgtitle(strcat('Results Report (selected Muscle Activations with Normdata):',{' '}, prefix,{' - '}, condition,{' - '}, strrep(subjectName,'_',{' '})),'FontWeight','bold');
    msls_names = strrep(msls_subNorm,'_', ' ');

    % Load NormData
    load(path.NormEMG);

    for i = 1:length(msls_subNorm)

        % Plot data
        subplot(3,3,i);
        hold on
        label_r = (strcat('forceset_',msls_subNorm{i},'r'));
        label_l = (strcat('forceset_',msls_subNorm{i},'l'));

        % Both
        if isfield(results_perSub.('r').MuscleActivations,label_r) && isfield(results_perSub.('l').MuscleActivations,label_l)
            dat_r = results_perSub.('r').MuscleActivations.(label_r);
            dat_l = results_perSub.('l').MuscleActivations.(label_l);

            hle = plot(dat_r,'LineWidth',line_width, 'Color', 'r'); %'r'
            hre = plot(dat_l,'LineWidth',line_width, 'Color', 'b'); %, 'LineStyle', '--'); %'l'
            s_tmp = '(L/R)';

            cIC_r = mean((results_perSub.('r').Events.cIC - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cTO_r = mean((results_perSub.('r').Events.cTO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            TO_r =  mean((results_perSub.('r').Events.TO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cIC_l = mean((results_perSub.('l').Events.cIC - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            cTO_l = mean((results_perSub.('l').Events.cTO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            TO_l =  mean((results_perSub.('l').Events.TO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time

            cIC = mean([cIC_r, cIC_l]);
            cTO = mean([cTO_r, cTO_l]);
            TO = mean([TO_r, TO_l]);

            % Only right
        elseif isfield(results_perSub.('r').MuscleActivations,label_r) && ~isfield(results_perSub.('r').MuscleActivations,label_l)
            dat_r = results_perSub.('r').MuscleActivations.(label_r);
            dat_l = nan(size(dat_r));
            hre = plot(dat_r,'LineWidth',line_width, 'Color', 'r');% 'r';
            s_tmp = '(R)';

            cIC = mean((results_perSub.('r').Events.cIC - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cTO = mean((results_perSub.('r').Events.cTO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            TO =  mean((results_perSub.('r').Events.TO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time

            % Only left
        elseif isfield(results_perSub.('l').MuscleActivations,label_l) && ~isfield(results_perSub.('l').MuscleActivations,label_r)
            dat_l = results_perSub.('l').MuscleActivations.(label_l);
            dat_r = nan(size(dat_l));
            hle = plot(dat_l,'LineWidth',line_width, 'Color', 'b');% 'l');
            s_tmp = '(L)';

            cIC = mean((results_perSub.('l').Events.cIC - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            cTO = mean((results_perSub.('l').Events.cTO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            TO =  mean((results_perSub.('l').Events.TO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time

        end

        box on;
        ylim([0 1]);
        ylabel(msls_names{i});

        % Add cTO, TO
        hold on;
        y_min = (min(min([dat_r dat_l])));
        y_max = (max(max([dat_r dat_l])));
        hcTO = line([cTO cTO],[0 1],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        hTO  = line([TO TO],[0 1],'Color','k', 'LineStyle', '-', 'LineWidth', 0.5);
        line([cIC cIC],[0 1],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        ylim([0 1]);
        numFrames = size(dat_r,1); % get number of frames
        xlim([0 numFrames]); % get number of frames]);
        hold off

        % Plot Norm Values
        hold on;
        % Plot Norm Values only if walking trial
        if strcmp(trialType, 'walking')
            if strcmp(msls_norm{i},'nan')
            else
                % Amplitude normalization
                for m = 1:size(EMGnorm.(msls_norm{i}),2)
                    tmp_signal = EMGnorm.(msls_norm{i})(:,m);
                    emg_dat(:,m) = (tmp_signal - (min(tmp_signal))) / (((max(tmp_signal))) - (min(tmp_signal))); % Min-Max normalization
                end
                norm_mean = mean(emg_dat,2);
                sf = y_max/max(norm_mean); % calculate scaling factor to have similar peak value between norm and muscle activations
                norm_std = std(emg_dat,0,2);
                norm_std = interpft(norm_std,length(dat_r)); % apply scaling factor and normalize to data length (IC-ICi)

                norm_curve = interpft(norm_mean*sf,length(dat_r)); % apply scaling factor
                plot(norm_curve,'k','LineWidth',1.5);
                plot(norm_curve+1*norm_std,'k--','LineWidth',0.5);
                plot(norm_curve-1*norm_std,'k--','LineWidth',0.5);
            end
        end

        % Last plotting tweaks
        if i > 6
            xlabel('Frames or time (%)');
        end

    end

    %% Plot Contact Force from Force Reporter
    hfig_CF = figure;
    set(hfig_CF,'units','centimeters','position',[5,15,30,8]);
    orient(hfig_CF,'landscape');
    sgtitle(strcat('Results Report (Contact Forces):',{' '}, prefix,{' - '}, condition,{' - '}, strrep(subjectName,'_',{' '}), '; R = red | L = blue'),'FontWeight','bold');
    tf_contactF_label = strrep(tf_contactF,'.','_');

    for i = 1:length(tf_contactF_label)

        % Plot data
        subplot(1,3,i);
        label_r = char(strcat(tf_contactF_label(i),'_r'));
        label_l = char(strcat(tf_contactF_label(i),'_l'));

        % Both
        if isfield(results_perSub.('r').ContactForces,label_r) && isfield(results_perSub.('l').ContactForces,label_l)
            dat_r = results_perSub.('r').ContactForces.(label_r)./(SubjInfo.MetaData.bodymassFromC3D*9.81); % Normalize to Bodymass * 9.81; Use only the Body mass from first node, should be the same anyway, and in case of different amount of l/r there will be otherwise a problem
            dat_l = (results_perSub.('l').ContactForces.(label_l)./(SubjInfo.MetaData.bodymassFromC3D*9.81));

            % Normalize z on the left side only to display all with same sign conventions
            if strcmp(label_l(end-2:end), 'z_l'); dat_l = dat_l * -1; end

            hold on
            hre = plot(dat_r,'LineWidth',line_width, 'Color', 'r');% [221,28,119]/255);
            hle = plot(dat_l,'LineWidth',line_width, 'Color', 'b');% [201,08,109]/255, 'LineStyle', '--');
            s_tmp = '(L/R)';

            cIC_r = mean((results_perSub.('r').Events.cIC - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cTO_r = mean((results_perSub.('r').Events.cTO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            TO_r =  mean((results_perSub.('r').Events.TO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cIC_l = mean((results_perSub.('l').Events.cIC - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            cTO_l = mean((results_perSub.('l').Events.cTO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            TO_l =  mean((results_perSub.('l').Events.TO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time

            cIC = mean([cIC_r, cIC_l]);
            cTO = mean([cTO_r, cTO_l]);
            TO = mean([TO_r, TO_l]);



            % Only right
        elseif isfield(results_perSub.('r').ContactForces,label_r) && ~isfield(results_perSub.('r').ContactForces,label_l)
            dat_r = results_perSub.('r').ContactForces.(label_r)./(SubjInfo.MetaData.bodymassFromC3D*9.81); % Normalize to Bodymass * 9.81;
            dat_l = nan(size(dat_r));
            hre = plot(dat_r,'LineWidth',line_width, 'Color', 'r');%  [221,28,119]/255);
            s_tmp = '(R)';

            cIC = mean((results_perSub.('r').Events.cIC - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cTO = mean((results_perSub.('r').Events.cTO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            TO =  mean((results_perSub.('r').Events.TO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time


            % Only left
        elseif isfield(results_perSub.('l').ContactForces,label_l) && ~isfield(results_perSub.('l').ContactForces,label_r)
            dat_l = results_perSub.('l').ContactForces.(label_l)./(SubjInfo.MetaData.bodymassFromC3D*9.81);

            % Normalize z on the left side only tor display all with same sign conventions
            if strcmp(label_l(end-2:end), 'z_l'); dat_l = dat_l * -1; end

            dat_r = nan(size(dat_l));
            hle = plot(dat_l,'LineWidth',line_width, 'Color', 'b');% [201,08,109]/255/255);
            s_tmp = '(L)';

            cIC = mean((results_perSub.('l').Events.cIC - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            cTO = mean((results_perSub.('l').Events.cTO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            TO =  mean((results_perSub.('l').Events.TO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time

        end

        box on;
        ylim([0 1]);
        if i == 1
            tmpLeg = 'anterior-posterior';
        elseif i == 2
            tmpLeg = 'vertical';
        elseif i == 3
            tmpLeg = 'medio-lateral';
        end

        ylabel({char(strcat(strrep(strcat(label_r(1:2),{' '},label_r(end-16:end-2),{' ' }),'_',' '),'[Body weight]'));tmpLeg});

        % Add cTO, TO, cIC
        hold on;

        % Plot the OrthoLoad data

        % Load the norm data
        load(path.NormKCF);
        KFCfn = {'Fy','F','Fx'};

        % Adjust sign for norm data
        if contains(tf_contactF{i},'force_x')
            curveKFC_mean_stance = interpft(mean(KFCnorm.NormBW.(KFCfn{i}),2),round(TO))*-1;
        else
            curveKFC_mean_stance = interpft(mean(KFCnorm.NormBW.(KFCfn{i}),2),round(TO));
        end

        if strcmp(trialType, 'walking')
            % Prepare data
            curveKFC_mean_stance = padarray(curveKFC_mean_stance,length(dat_r) - round(TO),'post')/100; % padd zeros to end, change to multipel of BW
            KFC_sd_stance = interpft(std(KFCnorm.NormBW.(KFCfn{i}),0,2),round(TO))/100; % change to multipel of BW
            KFC_sd_stance = padarray(KFC_sd_stance,length(dat_r)-round(TO),'post'); % padd zeros to end

            % Plot norm
            hOrth = plot(curveKFC_mean_stance,'k','LineWidth',line_width);
            plot(curveKFC_mean_stance+3*KFC_sd_stance,'k--','LineWidth',0.5);
            plot(curveKFC_mean_stance-3*KFC_sd_stance,'k--','LineWidth',0.5);
        end

        % Last plotting tweaks
        if i == 1 || i == 3; y_min = -0.5; y_max = 1; end
        if i == 2; y_min = -8; y_max = 0; end
        %y_min = (min(min([curveKFC_mean_stance-2*KFC_sd_stance, dat_r, dat_l])));
        %y_max = (max(max([curveKFC_mean_stance+2*KFC_sd_stance, dat_r, dat_l])));
        hcTO = line([cTO cTO],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        hTO = line([TO TO],[y_min y_max],'Color','k', 'LineStyle', '-', 'LineWidth', 0.5);
        line([cIC cIC],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        ylim([y_min y_max]);
        numFrames = size(dat_r,1); % get number of frames
        xlim([0 numFrames]);
        xlabel('Frames or time (%)');


    end

    %% Plot Contact Pressure from *.vtp
    if processVtp
        hfig_CP = figure;
        set(hfig_CP,'units','centimeters','position',[5,15,30,8]);
        orient(hfig_CP,'landscape');
        sgtitle(strcat('Results Report (Contact Force from Pressure ):',{' '}, prefix,{' - '}, condition,{' - '}, strrep(subjectName,'_',{' '}), '; R = red | L = blue'),'FontWeight','bold');

        % Initialize the eventdata for plotting
        cIC_r = NaN;
        cTO_r = NaN;
        TO_r = NaN;
        cIC_l = NaN;
        cTO_l = NaN;
        TO_l = NaN;

        % Total force
        subplot(1,3,1);
        if isfield(results_perSub.('r').ContactPressure,'TFvForceTot_BW_r') %%Check if field exist
            hright = plot(results_perSub.('r').ContactPressure.TFvForceTot_BW_r, 'LineWidth', line_width, 'Color', 'r');
            hold on;

            cIC_r = mean((results_perSub.('r').Events.cIC - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            cTO_r = mean((results_perSub.('r').Events.cTO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
            TO_r =  mean((results_perSub.('r').Events.TO - results_perSub.('r').Events.IC)./(results_perSub.('r').Events.ICi - results_perSub.('r').Events.IC))*100; % calculate in % of gait cycle time
        end

        if isfield(results_perSub.('l').ContactPressure,'TFvForceTot_BW_l') %%Check if field exist
            hleft = plot(results_perSub.('l').ContactPressure.TFvForceTot_BW_l, 'LineWidth', line_width, 'Color', 'b');
            hold on;

            cIC_l = mean((results_perSub.('l').Events.cIC - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            cTO_l = mean((results_perSub.('l').Events.cTO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
            TO_l =  mean((results_perSub.('l').Events.TO - results_perSub.('l').Events.IC)./(results_perSub.('l').Events.ICi - results_perSub.('l').Events.IC))*100; % calculate in % of gait cycle time
        end

        % Calc IC, etc.
        cIC = mean([cIC_r cIC_l], 'omitnan');
        cTO = mean([cTO_r, cTO_l], 'omitnan');
        TO = mean([TO_r, TO_l], 'omitnan');

        % Some plotting tweaks
        y_min = 0; %(min(min([resultsSelected_perSub.vForceTot_BW_r, resultsSelected_perSub.vForceTot_BW_l])));
        y_max = 8; %(max(max([resultsSelected_perSub.vForceTot_BW_r, resultsSelected_perSub.vForceTot_BW_l])));
        hcTO = line([cTO cTO],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        hTO = line([TO TO],[y_min y_max],'Color','k', 'LineStyle', '-', 'LineWidth', 0.5);
        line([cIC cIC],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        ylim([y_min y_max]);
        if isfield(results_perSub.('r').ContactPressure,'TFvForceTot_BW_r') %%Check if field exist
            numFrames = size(results_perSub.('r').ContactPressure.TFvForceTot_BW_r,1); % get number of frames
        else
            numFrames = size(results_perSub.('l').ContactPressure.TFvForceTot_BW_l,1); % get number of frames
        end

        xlim([0 numFrames]);
        xlabel('Frames or % gait cycle');
        ylabel('Total cont. force [N/ (body mass*g)]');
        if isfield(results_perSub.('r').ContactPressure,'TFvForceTot_BW_r') && isfield(results_perSub.('l').ContactPressure,'TFvForceTot_BW_l') && ~isempty(results_perSub.('r').ContactPressure.TFvForceTot_BW_r) && ~isempty(results_perSub.('l').ContactPressure.TFvForceTot_BW_l)
            legend(([hright(1), hleft(1)]),'Right','Left');
        elseif isfield(results_perSub.('r').ContactPressure,'TFvForceTot_BW_r') && ~isempty(results_perSub.('r').ContactPressure.TFvForceTot_BW_r)
            legend(hright(1),'Right');
        elseif isfield(results_perSub.('l').ContactPressure,'TFvForceTot_BW_l') && ~isempty(results_perSub.('l').ContactPressure.TFvForceTot_BW_l)
            legend(hleft(1),'Left');
        end


        % Medial force
        subplot(1,3,2);
        if isfield(results_perSub.('r').ContactPressure,'TFvForceMed_BW_r') %%Check if field exist
            plot(results_perSub.('r').ContactPressure.TFvForceMed_BW_r, 'LineWidth', line_width,'Color', 'r', 'LineStyle', '-');
            hold on;
        end
        if isfield(results_perSub.('l').ContactPressure,'TFvForceMed_BW_l') %%Check if field exist
            plot(results_perSub.('l').ContactPressure.TFvForceMed_BW_l, 'LineWidth', line_width,'Color', 'b', 'LineStyle', '-');
            hold on;
        end
        if isfield(results_perSub.('r').ContactPressure,'TFvForceMed_BW_r') && ~isempty(results_perSub.('r').ContactPressure.TFvForceMed_BW_r) %%Check if field exist
            numFrames = size(results_perSub.('r').ContactPressure.TFvForceMed_BW_r,1); % get number of frames
        elseif isfield(results_perSub.('l').ContactPressure,'TFvForceMed_BW_l') && ~isempty(results_perSub.('l').ContactPressure.TFvForceMed_BW_l)
            numFrames = size(results_perSub.('l').ContactPressure.TFvForceMed_BW_l,1); % get number of frames
        end

        % Some plotting tweaks
        xlim([0 numFrames]);
        xlabel('Frames or % gait cycle');
        hcTO = line([cTO cTO],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        hTO = line([TO TO],[y_min y_max],'Color','k', 'LineStyle', '-', 'LineWidth', 0.5);
        line([cIC cIC],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        ylim([y_min y_max]);
        xlim([0 numFrames]);
        xlabel('% gait cycle');
        ylabel('Med. cont. force [N/ (body mass*g)]');

        % Lateral force
        subplot(1,3,3);
        if isfield(results_perSub.('r').ContactPressure,'TFvForceLat_BW_r') %%Check if field exist
            plot(results_perSub.('r').ContactPressure.TFvForceLat_BW_r, 'LineWidth', line_width,'Color', 'r', 'LineStyle', '-');
            hold on;
        end
        if isfield(results_perSub.('l').ContactPressure,'TFvForceLat_BW_l')  %%Check if field exist
            plot(results_perSub.('l').ContactPressure.TFvForceLat_BW_l, 'LineWidth', line_width,'Color', 'b', 'LineStyle', '-');
            hold on;
        end
        if isfield(results_perSub.('r').ContactPressure,'TFvForceLat_BW_r') && ~isempty(results_perSub.('r').ContactPressure.TFvForceLat_BW_r) %%Check if field exist
            numFrames = size(results_perSub.('r').ContactPressure.TFvForceLat_BW_r,1); % get number of frames
        elseif isfield(results_perSub.('l').ContactPressure,'TFvForceLat_BW_l') && ~isempty(results_perSub.('l').ContactPressure.TFvForceLat_BW_l)
            numFrames = size(results_perSub.('l').ContactPressure.TFvForceLat_BW_l,1); % get number of frames
        end

        % Some plotting tweaks
        xlim([0 numFrames]);
        xlabel('Frames or % gait cycle');
        hcTO = line([cTO cTO],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        hTO = line([TO TO],[y_min y_max],'Color','k', 'LineStyle', '-', 'LineWidth', 0.5);
        line([cIC cIC],[y_min y_max],'Color','r', 'LineStyle', '--', 'LineWidth', 0.5);
        ylim([y_min y_max]);
        xlim([0 numFrames]);
        xlabel('Frames or time (%)');
        ylabel('Lat. cont. force [N/ (body mass*g)]');

    end

    %% Save file
    subResults.perTrial = resultsAll_perTrial;
    subResults.perSubject = results_perSub;
    subResults.InputData = InputData;
    subResults.SubjInfo = SubjInfo; % Add Model Personalization & SubjInfo
    
    % Add version information
    try
        path2Version = path2setupFiles;
        
        % Get the parent directory three levels above.
        for i = 1:3            
            path2Version = fileparts(path2Version);
        end

        curVersion = readLastLine(fullfile(path2Version, 'version.md'));
        subResults.VersionPostProcessing = curVersion;
    end

    % Save files
    if ~isempty(prefix); prefix = strcat(prefix,'-'); end

    % Create output folder
    outputFolder = char(strcat(workingDirectory,'JAM\allResultsFigures\'));
    if ~logical(exist(outputFolder, 'dir'))
        mkdir(outputFolder)
    end

    % Create output folder at top level
    outputFolderGroupData = char(fullfile(strcat(rootDirectory,'_comak-groupData\')));
    if ~logical(exist(outputFolderGroupData, 'dir'))
        mkdir(outputFolderGroupData)
    end

    % Make sure that no other data from same individual are already
    % stored in the folder, if so add custome label to "subjectName"
    ls = dir(fullfile(outputFolderGroupData, strcat(subjectName,'*', prefix, condition)));
    cfiles = {ls.name};
    nFiles = length(cfiles);

    if nFiles == 0
        subjectName2save = subjectName;
    else
        suffix = 'a':'z';
        subjectName2save = strcat(subjectName, suffix(nFiles));
    end

    saveas(hfig_GRF,char(fullfile(strcat(outputFolder, subjectName,'-', prefix, condition,'-GRFs-', '-JAM-Results-AllTrials.png'))));
    saveas(hfig_ComakKinem,char(fullfile(strcat(outputFolder, subjectName,'-', prefix, condition,'-ComakKinem', '-JAM-Results-AllTrials.png'))));
    saveas(hfig_Kinem,char(fullfile(strcat(outputFolder, subjectName,'-', prefix, condition,'-Kinem', '-JAM-Results-AllTrials.png'))));
    saveas(hfig_InvDyn,char(fullfile(strcat(outputFolder, subjectName,'-', prefix, condition,'-InvDyn', '-JAM-Results-AllTrials.png'))));
    saveas(hfig_MF,char(fullfile(strcat(outputFolder, subjectName,'-', prefix, condition,'-MF', '-JAM-Results-AllTrials.png'))));
    saveas(hfig_MA,char(fullfile(strcat(outputFolder, subjectName,'-', prefix, condition,'-MA', '-JAM-Results-AllTrials.png'))));
    saveas(hfig_CF,char(fullfile(strcat(outputFolder, subjectName,'-', prefix, condition,'-KCF', '-JAM-Results-AllTrials.png'))));
    if processVtp; saveas(hfig_CP,char(fullfile(strcat(outputFolder, subjectName,'-', prefix, condition,'-CP', '-JAM-Results-AllTrials.png')))); end
    save(char(fullfile(strcat(workingDirectory,'JAM\', subjectName,'-', prefix, condition,'-JAM-Results-All-Trials.mat'))),'subResults');

    save(char(fullfile(strcat(outputFolderGroupData, subjectName2save,'-', prefix, condition,'-JAM-Results-All-Trials.mat'))),'subResults', '-v7.3');

    % Now close all figures
    close all;
end
end

