function loops4Comak(rootDirectory, workingDirectories, staticC3dFiles, conditions, labFlag, path2GenericModels, path2bin, path2opensim, ...
    path2setupFiles, tf_angle_r, tf_angle_l, firstContact_L, firstContact_R, contactE, MW, prefix, timeNorm, maxCmd, ...
    thresholdCpuLoad, catchErrors, writeVtp, useGenericSplines, lockSubtalar4Scaling, scaleMuscleStrength, manualMusScaleF, ...
    markerSet, bodyheightGenericModel, addPelvisHelperMarker, pelvisMarker4nonUniformScaling, ...
    tf_angle_fromSource, torsiontool, useDirectKinematics4TibRotEstimationAsFallback, tib_torsion_LeftMarkers, tib_torsion_RightMarkers, forceTrcMotCreation, ...
    dataAugmentation, ForceModelCreation, performPostProcessing, trialType, timeNormFlag, renameC3DFiles2enfDescription, vtp2keep, deleteVtps, jamSettings, ...
    checkAndAdaptMomArms, useASTool, repoPaths, allowAutoRestart, thresholdFreeRAM, useC3Devents, scalePelvisManually, pelvisWidthGenericModel, ...
    useStatic4FrontAlignmentAsFallback, tibTorsionAdaptionMethod, useCPUThreshold, varNameKneeAngle_c3d, iterationCntRestart)


%% In case user selected the option that matlab can restart automatically in case of low memory.

% The follwoing <currentPath> needs to be created automatically since for a restart we do not have
% any inputs to the function before loading the temp workspace.
tmpPath = mfilename('fullpath');
[currentPath, ~, ~] = fileparts(fileparts(fileparts(tmpPath))); % jump up three folder lvls.
currentPath = fullfile(currentPath);

% Check if a workspace file exists to determine if we are resuming.
checkPointFilePath = fullfile(currentPath, 'workspaceCheckpoint4AutoRestart.mat');
if exist(checkPointFilePath, 'file')
    load(checkPointFilePath);
    delete(checkPointFilePath); % Delete the file after loading to prevent further restarts

    % Set the paths for Matlab again since they got lost by the restart.
    addpath(genpath(repoPaths.repo));
    addpath(genpath(repoPaths.commonFiles));

    % Make user aware that workspace was loaded from file instead of
    % created to prevent an unintended loading.
    warning("The workspace was loaded from an earlier *.tmp file. If this was not intended check if an old <workspaceCheckpoint4AutoRestart.mat is located in the repo folder.>")
    pause(60*5)
else
    i_wd = 1; % Initialize i_wd if starting fresh
    kickOffRestart = false; % Set to false initially
end

%% Load data augmentation set if user selected to augment simulations
augN = 1; % set this to one to only run the loop once unless dataAugmentation is set to true
if dataAugmentation
    load(fullfile(path2setupFiles, 'dataAugmentationSet.mat'));
    augN = height(dataAugmentationSet); %number of augmentation cycles
end

%% Now loop through folders
errN = 0; % Number of errors occured and catched
failures = struct('cond', {}, 'wd', {}, 'err', {}); % collect catched errors
tStart = tic; % Start timer
numFiles = 1; %count number of files processed
overFlowThreshold = 300; % default = 300 (100-500); Used to pause the skript every eg 500 trials and then force to close all open cmd windows.

% Batchcount for comak for each trial in the working directory
batchCount = 0; % Used to limit the number of open cmd windows

% Loop through wd
for i_wd = i_wd : length(workingDirectories)

    % Loop for potential data augmentation
    for i_dataAug = 1 : augN

        % Set the variables based on the augmentation file
        if dataAugmentation
            tf_angle_fromSource = dataAugmentationSet.tf_angle_fromStatic(i_dataAug);
            tf_angle_r = dataAugmentationSet.tf_angle_r(i_dataAug);
            tf_angle_l = dataAugmentationSet.tf_angle_l(i_dataAug);
            torsiontool.tibTorsionAdaption = 0; % under construction
            tt_angle_r = 0; % under construction
            tt_angle_l = 0; % under construction
        end
        try
            % Set current prefix
            cPrefix = prefix{i_dataAug}; % I either get one prefix from the current workflow OR a set of prefixes from the dataaugmentation mode

            % Set current workingDirectory & static trial
            % Check if comak subfolder in working directory exists, otherwise create folder
            rootWorkingDirectory = fullfile(workingDirectories{i_wd});

            % Create prefix-specific WD
            workingDirectory = fullfile(strcat(workingDirectories{i_wd},'comak-', cPrefix,'\'));

            if ~logical(exist(workingDirectory, 'dir'))
                mkdir(workingDirectory)
            end

            % Set static file
            staticC3d = staticC3dFiles{i_wd};

            % Check if it is a SEBT trial and then rename files
            if sum(contains(conditions, 'SEBT')) > 0
                % Prepare mSEBT data and rename *.c3d/*.enf files in the working directory so that each file contains the mSEBT direction
                renameSEBTc3D(rootWorkingDirectory);
            end

            %Rename c3d files in accordacne with the *.enf file
            %description, this is an OSS specific workflow and necessary to
            %get the correct naming for the conditions!
            if renameC3DFiles2enfDescription
                disp('>>>>> All *.c3d files will be renamed to the *.enf description!')
                renameC3D2enfDescription(rootWorkingDirectory);
            end

            % Track to skip all trials of one side if sec. constrain simulation
            % failed once (for all SEBT conditions in workingDirectory)
            skipSideInBatchL = 'none';
            skipSideInBatchR = 'none';

            % Loop for condition
            for i_cond = 1 : size(conditions,2)
                try
                    % Initialize var to track the number of processed files in a WD for specific cond.
                    proFilesCount = 0;

                    % Set mSEBT condition: 'mSEBT-AT','mSEBT-PM','mSEBT-PL' and run comak separately
                    condition = conditions{i_cond};

                    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % RUN COMAK-JAM %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

                    % Start message
                    disp('*********************************************  COMAK started  **********************************************');

                    % Calculates Input data for osimjam_workflow for all files specified by 'condition' and creates all *.trc and *.mot files
                    [InputData, errN, failures] = prepareInputData(rootWorkingDirectory, workingDirectory, staticC3d, condition, labFlag, markerSet, addPelvisHelperMarker, pelvisMarker4nonUniformScaling, forceTrcMotCreation, errN, failures, useC3Devents);

                    % Get trial names for all condition files
                    trials = fieldnames(InputData);

                    % Copy Geometry folder once to working directory
                    if ~logical(exist(fullfile(workingDirectory,'Geometry'),'dir'))
                        copyfile(fullfile(path2GenericModels,'_Geometry'), fullfile(workingDirectory,'Geometry'));
                    end

                    % Prepare data to (scale) the models for both body sides and also scale contact geometry manually, because these are not scaled by opensim (seems to be a bug)
                    bodymass = InputData.(trials{1}).Bodymass;      % get body mass from first trial
                    BodyHeight = InputData.(trials{1}).BodyHeight;  % get body mass from first trial
                    static = InputData.(trials{1}).static_trcPath;  % static trc path from first trial
                    sub_name = InputData.(trials{1}).subjectName;   % subject name

                    % Create one sample *.trc file for R and L. This is used for the function <adaptWrappingObjects...> that checks the muscle moment
                    % arms in the prepareScaledModel function.
                    if checkAndAdaptMomArms

                        % Get one trial for L/R for IK.
                        idxTrialsR = find(contains(cellfun(@(x) x(end), trials, 'UniformOutput', false),'r'),1);
                        idxTrialsL = find(contains(cellfun(@(x) x(end), trials, 'UniformOutput', false),'l'),1);

                        % Check if a file was found for R.
                        if ~isempty(idxTrialsR)
                            sampleInputR = InputData.(trials{idxTrialsR});
                            checkAndAdaptMomArmsR = true;
                        else
                            sampleInputR = 'NA';
                            checkAndAdaptMomArmsR = false;
                        end

                        % Check if a file was found for L.
                        if ~isempty(idxTrialsL)
                            sampleInputL = InputData.(trials{idxTrialsL});
                            checkAndAdaptMomArmsL = true;
                        else
                            sampleInputL = 'NA';
                            checkAndAdaptMomArmsL = false;
                        end
                    else
                        sampleInputR = 'NA';
                        sampleInputL = 'NA';
                        checkAndAdaptMomArmsR = false;
                        checkAndAdaptMomArmsL = false;
                    end

                    % Start to collect some data for subject info file.
                    dataFile = fullfile(rootWorkingDirectory, 'data.xml');
                    if isfile(dataFile)
                        persInfo = readstruct(dataFile);

                        % Make sure there are no field types that cannot be read in python.
                        persInfo = convertFieldsToChar(persInfo);

                        SubjInfo.MetaData = persInfo;
                        SubjInfo.MetaData.bodymassFromC3D = bodymass;
                        SubjInfo.MetaData.bodyheightFromC3D = BodyHeight;
                        SubjInfo.MetaData.description = 'This node contains information stored in a separate <data> file in the working directory. Note that if a variable such as AVR exists here, it does not necessarily mean it was used for personalization.';
                    else
                        SubjInfo.MetaData.bodymassFromC3D = bodymass;
                        SubjInfo.MetaData.bodyheightFromC3D = BodyHeight;
                        SubjInfo.MetaData.description = 'There was no additional "data-file" available.';
                    end

                    % Add version number so one knows with which version
                    % data were simulated.
                    try
                        path2Version = path2setupFiles;

                        % Get the parent directory three levels above.
                        for i = 1:3
                            path2Version = fileparts(path2Version);
                        end

                        curVersion = readLastLine(fullfile(path2Version, 'version.md'));
                        SubjInfo.VersionProcessing = curVersion;
                    end

                    % Set flags to specify that yet not models were scaled.
                    flag_modelScaledRight = false;
                    flag_modelScaledLeft = false;

                    for i = 1 : length(trials)

                        IC = InputData.(trials{i}).IC;
                        ICi = InputData.(trials{i}).ICi;
                        cIC = InputData.(trials{i}).cIC;
                        cTO = InputData.(trials{i}).cTO;
                        TO = InputData.(trials{i}).TO;
                        BW = InputData.(trials{i}).Bodymass * 9.81;
                        side = InputData.(trials{i}).Side;
                        path2c3d = (InputData.(trials{i}).c3dPath);
                        path2trc = (InputData.(trials{i}).trcPath);
                        path2mot = (InputData.(trials{i}).motPath);
                        path2enf = (InputData.(trials{i}).enfPath);
                        name = (InputData.(trials{i}).name);

                        % Prepare (scale) the models for both body sides
                        % and also scale contact geometry manually, because these are not scaled by opensim (seems to be a bug).
                        switch side
                            case 'right'
                                if ~flag_modelScaledRight
                                    [path2Model_right, tf_angle_right, torsionTool_right, tf_angle_fromSource_right, MomArmsResolved_right] = prepareScaledModel(rootWorkingDirectory, workingDirectory, path2GenericModels, path2bin, path2opensim, bodymass, static, 'right', ...
                                        labFlag, lockSubtalar4Scaling, scaleMuscleStrength, manualMusScaleF, cPrefix, bodyheightGenericModel, BodyHeight, ...
                                        tf_angle_r, tf_angle_fromSource, staticC3d, torsiontool, tib_torsion_RightMarkers, ForceModelCreation, checkAndAdaptMomArmsR, sampleInputR, useASTool, useDirectKinematics4TibRotEstimationAsFallback, InputData, ...
                                        scalePelvisManually, pelvisWidthGenericModel, useStatic4FrontAlignmentAsFallback, tibTorsionAdaptionMethod, varNameKneeAngle_c3d); % % % strcat(rootWorkingDirectory, staticC3d) statt staticC3d

                                    % Add info about model personalization to InputData
                                    % logicals
                                    SubjInfo.UsedData4Personalization.r.Logicals.TF_adaption = char(tf_angle_fromSource_right);
                                    SubjInfo.UsedData4Personalization.r.Logicals.AV_adaption = char(torsionTool_right.femurAntetorsionAdaption_r);
                                    SubjInfo.UsedData4Personalization.r.Logicals.TT_adaption = char(torsionTool_right.tibTorsionAdaption_r);
                                    SubjInfo.UsedData4Personalization.r.Logicals.NS_adaption = char(torsionTool_right.neckShaftAdaption_r);
                                    SubjInfo.UsedData4Personalization.l.Logicals.TT_method = tibTorsionAdaptionMethod;
                                    SubjInfo.UsedData4Personalization.r.Logicals.MomArmsResolved = MomArmsResolved_right;

                                    % Values
                                    SubjInfo.UsedData4Personalization.r.Values.TF_angle = tf_angle_right;
                                    SubjInfo.UsedData4Personalization.r.Values.TT_angle = torsionTool_right.TTR;
                                    SubjInfo.UsedData4Personalization.r.Values.NS_angle = torsionTool_right.NSAR;
                                    SubjInfo.UsedData4Personalization.r.Values.AV_angle = torsionTool_right.AVR;

                                    % Save Subject Info to get the left and right data.
                                    save(strcat(workingDirectory,'JAM\', char(strrep(sub_name,' ','_')),'-',condition,'-JAM-SubjInfo.mat'),'SubjInfo');

                                    % Set flag to know for next round that model was scaled already.
                                    flag_modelScaledRight = true;
                                end

                            case 'left'
                                if ~flag_modelScaledLeft
                                    [path2Model_left, tf_angle_left, torsionTool_left, tf_angle_fromSource_left, MomArmsResolved_left] =  prepareScaledModel(rootWorkingDirectory, workingDirectory, path2GenericModels, path2bin, path2opensim, bodymass, static, 'left', ...
                                        labFlag, lockSubtalar4Scaling, scaleMuscleStrength, manualMusScaleF, cPrefix, bodyheightGenericModel, BodyHeight, ...
                                        tf_angle_l, tf_angle_fromSource, staticC3d, torsiontool, tib_torsion_LeftMarkers, ForceModelCreation, checkAndAdaptMomArmsL, sampleInputL, useASTool, useDirectKinematics4TibRotEstimationAsFallback, InputData, ...
                                        scalePelvisManually, pelvisWidthGenericModel, useStatic4FrontAlignmentAsFallback, tibTorsionAdaptionMethod, varNameKneeAngle_c3d); % % % strcat(rootWorkingDirectory, staticC3d) statt staticC3d

                                    % Add info about model personalization to InputData
                                    % logicals
                                    SubjInfo.UsedData4Personalization.l.Logicals.TF_adaption = char(tf_angle_fromSource_left);
                                    SubjInfo.UsedData4Personalization.l.Logicals.AV_adaption = char(torsionTool_left.femurAntetorsionAdaption_l);
                                    SubjInfo.UsedData4Personalization.l.Logicals.TT_adaption = char(torsionTool_left.tibTorsionAdaption_l);
                                    SubjInfo.UsedData4Personalization.l.Logicals.NS_adaption = char(torsionTool_left.neckShaftAdaption_l);
                                    SubjInfo.UsedData4Personalization.l.Logicals.TT_method = tibTorsionAdaptionMethod;
                                    SubjInfo.UsedData4Personalization.l.Logicals.MomArmsResolved = MomArmsResolved_left;

                                    % Values
                                    SubjInfo.UsedData4Personalization.l.Values.TF_angle = tf_angle_left;
                                    SubjInfo.UsedData4Personalization.l.Values.TT_angle = torsionTool_left.TTL;
                                    SubjInfo.UsedData4Personalization.l.Values.NS_angle = torsionTool_left.NSAL;
                                    SubjInfo.UsedData4Personalization.l.Values.AV_angle = torsionTool_left.AVL;

                                    % Save Subject Info to get the left and right data.
                                    save(strcat(workingDirectory,'JAM\', char(strrep(sub_name,' ','_')),'-',condition,'-JAM-SubjInfo.mat'),'SubjInfo');

                                    % Set flag to know for next round that model was scaled already.
                                    flag_modelScaledLeft = true;
                                end
                        end

                        % Create external loads file
                        path2extLoad = createExtLoadsFile(path2enf, path2mot, name, firstContact_L, firstContact_R);

                        % Run COMAK for left or right side
                        if strcmp(side, 'left')

                            % Run the COMAK-JAM pipeline, each trial in one cmd window
                            disp(char(strcat('>>>>> Started trial:',{' '},name, '_', side)));

                            % Run sec. constrain simulations
                            if ~strcmp(skipSideInBatchL, 'left') % if simulation failed earlier it will ignore this side for the current batch
                                [secondary_constraint_function_file, second_constraints, secondary_coupled_coordinate] = run_secConstrainSimulation(workingDirectory, path2bin, path2opensim, path2setupFiles, side, path2trc, path2mot, path2Model_left, IC, ICi, cPrefix, tf_angle_l, labFlag, useGenericSplines);

                                % Check if simulation worked otherwise skip this trial
                                [flagExistsL, skipSideInBatchL] = checkIfSecConstrFileExists(workingDirectory,'*IK_second_coord_constraint_functions_left*.xml', side, 60*10); % note that *... * are necessary on both sides. generic ... tf-adapted
                            end

                            % Run COMAK/JAM simulation if everything is ready
                            if flagExistsL
                                osimjam_workflow(workingDirectory, path2bin, path2opensim, path2setupFiles, side, name, path2trc, path2mot, path2extLoad, path2Model_left, IC, cTO, cIC, TO, ICi, contactE, MW, BW, cPrefix, tf_angle_r, tf_angle_l, timeNorm, secondary_constraint_function_file, second_constraints, secondary_coupled_coordinate, labFlag, writeVtp, jamSettings);
                            end

                        elseif strcmp(side, 'right')

                            % Run the COMAK-JAM pipeline, each trial in one cmd window
                            disp(char(strcat('>>>>> Started trial:',{' '}, name, '_', side)));

                            % Run sec. constrain simulations
                            if ~strcmp(skipSideInBatchR, 'right') % if simulation failed earlier it will ignore this side for the current batch
                                [secondary_constraint_function_file, second_constraints, secondary_coupled_coordinate] = run_secConstrainSimulation(workingDirectory, path2bin, path2opensim, path2setupFiles, side, path2trc, path2mot, path2Model_right, IC, ICi, cPrefix, tf_angle_r, labFlag, useGenericSplines);

                                % Check if simulation worked otherwise skip this trial
                                [flagExistsR, skipSideInBatchR] = checkIfSecConstrFileExists(workingDirectory,'*IK_second_coord_constraint_functions_right*.xml', side, 60*10); % note that *... * are necessary on both sides. generic ... tf-adapted
                            end

                            % Run COMAK/JAM simulation if everything is ready
                            if flagExistsR
                                osimjam_workflow(workingDirectory, path2bin, path2opensim, path2setupFiles, side, name, path2trc, path2mot, path2extLoad, path2Model_right, IC, cTO, cIC, TO, ICi, contactE, MW, BW, cPrefix, tf_angle_r, tf_angle_l, timeNorm, secondary_constraint_function_file, second_constraints, secondary_coupled_coordinate, labFlag, writeVtp, jamSettings);
                            end
                        end

                        %% Pause after maximum number of cmd windows are open
                        batchCount = batchCount + 1;
                        proFilesCount = proFilesCount + 1;

                        % Get processing time update
                        tEnd = seconds(toc(tStart));
                        tEnd.Format = 'hh:mm';

                        % If max. number of files reached or all files from condition forwarded display message and wait for next batch.
                        if batchCount == maxCmd
                            % Set the current number of processed files
                            % Display status
                            disp(' ');
                            disp(' ');
                            disp('*** Status Update ******************************************************************************************');
                            disp(char(strcat('Current working directory:', {' '}, workingDirectory)));
                            disp(char(strcat('Working directory',{' #'}, string(i_wd), {' '}, 'out of', {' #'}, string(length(workingDirectories)), '.')));
                            disp(char(strcat('Current condition:', {' '}, condition, {' out of { '}, strjoin(conditions, ', '), ' }.')));
                            if dataAugmentation; disp(char(strcat('Current data augmentation loop',{' #'}, string(i_dataAug), {' '}, 'out of', {' #'}, string(augN), '.'))); end
                            disp(strcat('Total files to process in current WD:..................', num2str(length(trials))));
                            disp(strcat('Processed files in current WD:.........................', num2str(proFilesCount)));
                            disp(strcat('Files waiting to be processed in current WD:...........', num2str(length(trials)-i)));
                            disp(strcat('Processed files in current batch:......................', num2str(batchCount)));
                            disp(strcat('Number of files forwarded to cmd window since start:...', num2str(numFiles)));
                            disp(strcat('Processing duration since <comak> start:',{' '}, string(tEnd),'(hh:mm).'));
                            disp('************************************************************************************************************');
                            disp(' ');

                            % To potentially prevent buffer overflow, make sure to close all fids in case fids are still open
                            fclose('all');

                            % Wait until ...
            				if useCPUThreshold
            					disp(strcat('-> Matlab paused! When CPU-load drops below the threshold of', {' '}, string(thresholdCpuLoad) ,{'% '},'the next batch of files will kick off ...'));
            					CpuLoadBasedPausing_WIN11(thresholdCpuLoad, 40);

                                % Set batch cnt back to zero.
                                batchCount = 0;
                            else
            					disp(strcat('-> Matlab paused! When the number of cmd windows drops below the threshold of N=', string(maxCmd) ,{' '},'of open cmd windows, the next batch of files will kick off ...'));
            					monitorCmdWindowsAndWait(5, 8, maxCmd);

                                % Set batch cnt back to zero.
                                batchCount = 0;
            				end

                            % Check how much RAM is left and take action if too low                            
                            freeRAMinPerc = measureFreeRAM;
                            if  freeRAMinPerc < thresholdFreeRAM % if below threshold then take action.
                                warning('Only %.0f%% free RAM left! I will wait for 1h and then will close all open CMD windows', freeRAMinPerc)
                                pause (60*60) % wait for 1h to finish open cmd windows
                                closeCmdWindows(); % now force to close open cmd windows
                                pause(120);
                            end

                            % Now measure again to make sure action was succesfull.
                            freeRAMinPerc = measureFreeRAM;
                            if  freeRAMinPerc < thresholdFreeRAM % if still below threshold then take action.
                                warning('Still only %.0f%% free RAM left after all CMD were closed! User action required! Free up RAM, e.g. by restarting Matlab.', freeRAMinPerc)
                                
                                % In case user allowed for autorestart, set flag to kickoff autorestart at end of loop.
                                if allowAutoRestart
                                    kickOffRestart = true;
                                else
                                    pause();
                                end
                            end

                            % Check if we reached a multiple of e.g. 300
                            if mod(i_wd, iterationCntRestart) == 0

                                % Allow to restart after x iterations.
                                if allowAutoRestart
                                    kickOffRestart = true;
                                else
                                    pause();
                                end
                            end

                            % Make sure that cmd windows that do not converge get closed after a while. This hopefully prevents any "buffer overflow" errors.
                            if numFiles > overFlowThreshold
                                disp(['>>>>>  After ', num2str(overFlowThreshold) ,' files I will take a 1h break. Afterwards all remaining cmd windows will be terminated.']);
                                pause(60*60*1);
                                closeCmdWindows(); % now force to close open cmd windows
                                pause(60);

                                % Adjust overFlowThreshold
                                overFlowThreshold = overFlowThreshold + overFlowThreshold;
                            end
                        end

                        numFiles = numFiles + 1;
                    end

                catch ME
                    if catchErrors
                        disp(char(strcat('>>>>> An error occured during processing of condition', {' "'}, condition, {'" '},'in wd:', {' '},  workingDirectory,{'. '}, 'Skipped condition in current wd!')));
                        fprintf('>>>>> Error message: %s\n', ME.message);
                        errN = errN + 1;
                        failures(errN).cond = condition;
                        failures(errN).wd = workingDirectory;
                        failures(errN).err = getReport(ME);
                    else
                        rethrow(ME)
                    end
                end

                %% Now run postprocessing if user selected this option
                if performPostProcessing

                    % Wait to make sure all batch files are finished
                    disp('>>>>> Waiting to postprocess the current batch of files ...');
                    thresholdCpuLoadPostProcessing = 10; % Define a threshold the CPU load has to fall below, default ~ 10%, 1% for 32-core server
                    CpuLoadBasedPausing(thresholdCpuLoadPostProcessing, 60*15) % check every X minutes if CPU load is below the threshold (e.g. 35%). Wait extra long here.

                    % Make sure the condition/prefix/workingDirectory are cell arrays
                    Condition4PostPro = {condition};
                    Prefix4PostP = {cPrefix};
                    workingDirectory4PostPro = {workingDirectories{i_wd}}; % use the wd without the added pipeline here; this will be done later.

                    % Use Matlab's parallel toolbox? Note that in this case errors are catched
                    % but not tracked since the parallel workers do not allow for this.
                    useParallelToolBox = false; % default = false; since I only use this function for small datasets
                    M = 1; % Set number of workers; for a 32-core server 20 seems ok.

                    % Run the post processing loop
                    loops4PostProcessing(rootDirectory, workingDirectory4PostPro, Condition4PostPro, path2setupFiles, Prefix4PostP, timeNormFlag, catchErrors, trialType, 'comak', writeVtp, useParallelToolBox, M);

                    % Final postprocessing message
                    disp(strcat('*********************************  COMAK postprocessing finished for <',workingDirectory, 'current trial  *********************************'));
                end

                % Remove unnecessary *.vtp files if user selected option
                if deleteVtps
                    cleanUpVtpFiles(vtp2keep, rootDirectory, '');
                end

            end

        catch ME
            if catchErrors
                disp(char(strcat('>>>>> An error occured during processing of wd:', {' '},  workingDirectory,{'. '}, 'Skipped wd!')));
                fprintf('>>>>> Error message: %s\n', ME.message);
                errN = errN + 1;
                failures(errN).cond = condition;
                failures(errN).wd = workingDirectory;
                failures(errN).err = getReport(ME);
            else
                rethrow(ME)
            end
        end
    end

    % Update status in local WorkingDirectories file located in the
    % rootDirectory. Note that it is important to update and save the file
    % during each WD loop. In case of a Matlab crash otherwise all info
    % would be lost.

    maxAttempts = 5; % Set the maximum number of attempts
    currentAttempt = 1; % Initialize attempt counter

    while currentAttempt <= maxAttempts
        try
            wdFile = fullfile(rootDirectory, 'workingDirectories.xlsx');
            data = readtable(wdFile);
            c_idx = find(strcmp(data.WorkingDirectories, rootWorkingDirectory));
            data.Simulation(c_idx) = 1;
            data.ModelWOadaptionRight(c_idx) = {MomArmsResolved_right};
            data.ModelWOadaptionLeft(c_idx) = {MomArmsResolved_left};
            writetable(data, wdFile);
            break;
        catch
            % Wait for some time before the next attempt
            pause(5);

            % Increment the attempt counter
            currentAttempt = currentAttempt + 1;
        end
    end

    % In case user selected the option that matlab can restart automatically in
    % case of low memory.
    if allowAutoRestart

        if kickOffRestart

            % Increase i_wd by one so when script reloads it willstart with next loop.
            i_wd = i_wd + 1;

            % Set restartFlag back to false to ensure it doesn't restart again.
            kickOffRestart = false; % Update the restart flag.

            % Save the current workspace to a file
            pause (60)
            warning('Saving workspace and restarting MATLAB!');
            save(checkPointFilePath);

            % Construct the command to restart MATLAB and run the same script
            matlab_command = ['matlab -r "run(''' mfilename('fullpath') ''');" &'];
            system(matlab_command);

            % Exit the current MATLAB session
            exit; 
        end
    end
end

% Save errors log as *.txt in root dir.
writetable(struct2table(failures), fullfile(rootDirectory,'MatlabErrorLog.xlsx'));

% End timer
tEnd = seconds(toc(tStart));
tEnd.Format = 'hh:mm';
disp(''); % new line
disp('************************************************************************************************************');
disp(strcat('>>>>>  Total number of matlab errors catched:',{' '}, string(errN), '. <<<<<'));
disp(strcat('>>>>>  Total processing duration:',{' '}, string(tEnd),'(hh:mm). <<<<<'));

