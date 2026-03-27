function loops4Models_parfor(rootDirectory, workingDirectories, staticC3dFiles, conditions, labFlag, path2GenericModels, path2opensim, path2setupFiles, tf_angle_r, tf_angle_l, ...
    firstContact_L, firstContact_R, prefix, maxCmd, thresholdCpuLoad, lockSubtalar4Scaling, ...
    scaleMuscleStrength, manualMusScaleF, markerSet, bodyheightGenericModel, addPelvisHelperMarker, pelvisMarker4nonUniformScaling, tf_angle_fromSource, torsiontool, useDirectKinematics4TibRotEstimationAsFallback, ...
    tib_torsion_LeftMarkers, tib_torsion_RightMarkers, forceTrcMotCreation, ForceModelCreation, renameC3DFiles2enfDescription, ...
    Model2Use, tasks, checkAndAdaptMomArms, useASTool, i_wd, useStatic4FrontAlignmentAsFallback, useC3Devents, useCPUThreshold, tibTorsionAdaptionMethod, pelvisWidthGenericModel, scalePelvisManually, ...
    varNameKneeAngle_c3d, compute_joint_centers_for_static_trc, jc_base_data)

try

    % Start timer
    tStart = tic;

    % Set current workingDirectory & static trial
    % Check if comak subfolder in working directory exists, otherwise
    % create folder
    rootWorkingDirectory = fullfile(workingDirectories{i_wd});

    % Set current prefix
    cPrefix = prefix{1}; % I either get one prefix from the current workflow OR a set of prefixes from the dataaugmentation mode

    % Create prefix-specific WD
    workingDirectory = fullfile(strcat(workingDirectories{i_wd}, Model2Use, '-', cPrefix,'\'));

    if ~logical(exist(workingDirectory, 'dir'))
        mkdir(workingDirectory)
    end

    % Set static file
    staticC3d = staticC3dFiles{i_wd};

    % Check if it is a SEBT trial and then rename files
    if sum(contains(conditions, 'SEBT')) > 0
        % Prepare mSEBT data and rename *.c3d/*.enf files in the working directory so that each file contains the mSEBT direction
        renameSEBTc3D(workingDirectory);
    end

    %Rename c3d files in accordacne with the *.enf file
    %description, this is an OSS specific workflow and necessary to
    %get the correct naming for the conditions!
    if renameC3DFiles2enfDescription
        disp('>>>>> All *.c3d files will be renamed to the *.enf description!')
        renameC3D2enfDescription(rootWorkingDirectory);
    end

    % Loop for condition
    for cond = 1 : size(conditions,2)
        % Initialize var to track the number of processed files in a WD for specific cond.
        proFilesCount = 0;

        % Set mSEBT condition: 'mSEBT-AT','mSEBT-PM','mSEBT-PL' and run comak separately
        condition = conditions{cond};

        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % RUN Pipeline %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % Start message
        disp(['****************************************  ', upper(Model2Use), ' pipeline started  **********************************************']);

        % Calculate Input data for workflow for all files specified by 'condition' and creates all *.trc and *.mot files
        % Note that the last input defines how the grf data are rotated, e.g. for the 'FHSTP-BIZ' lab or the 'OSS' lab.
        [InputData] = prepareInputData(rootWorkingDirectory, workingDirectory, staticC3d, condition, labFlag, markerSet, addPelvisHelperMarker, pelvisMarker4nonUniformScaling, forceTrcMotCreation, Model2Use, useC3Devents, compute_joint_centers_for_static_trc, jc_base_data);

        % Get trial names for all condition files
        trials = fieldnames(InputData);

        % Copy Geometry folder once to working directory
        if ~logical(exist(fullfile(workingDirectory,'Geometry'),'dir'))
            copyfile(fullfile(path2GenericModels,'_Geometry'), fullfile(workingDirectory,'Geometry'));
        end

        % Prepare (scale) the models for both body sides.
        bodymass = InputData.(trials{1}).Bodymass;      % get BW from first trial
        BodyHeight = InputData.(trials{1}).BodyHeight;      % get body mass from first trial
        static = InputData.(trials{1}).static_trcPath;  % static trc path from first trial
        sub_name = InputData.(trials{1}).subjectName;   % subject name

        % Create one sample *.trc file for R or L. This is used for the function <adaptWrappingObjects...> that checks the muscle moment
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

        % Select L or R trial randomly for MomArm CheckUp to make
        % sure not always the right side is used.

        if checkAndAdaptMomArmsR && checkAndAdaptMomArmsL % both are available.
            rndVal = randi([0, 1]); % random selection.
            if rndVal == 0 % Right
                sampleInput = sampleInputR;
                checkAndAdaptMomArms = checkAndAdaptMomArmsR;
            else
                sampleInput = sampleInputL; % Left
                checkAndAdaptMomArms = checkAndAdaptMomArmsL;
            end
        elseif checkAndAdaptMomArmsR
            sampleInput = sampleInputR; % Right
            checkAndAdaptMomArms = checkAndAdaptMomArmsR;
        else
            sampleInput = sampleInputL; % Left
            checkAndAdaptMomArms = checkAndAdaptMomArmsL;
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
        flag_modelScaled = false;

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


            % Prepare (scale) the models for both body sides.
            if ~flag_modelScaled
                [path2Model, torsionTool, tf_angle_fromSource_right, ...
                    tf_angle_fromSource_left, tf_angle_right, tf_angle_left, ...
                    MomArmsResolved, persInfoFromMarkers] = prepareScaledModel(rootWorkingDirectory, workingDirectory, path2GenericModels, path2opensim, bodymass, static, ...
                    labFlag, lockSubtalar4Scaling, scaleMuscleStrength, manualMusScaleF, cPrefix, bodyheightGenericModel, BodyHeight, ...
                    tf_angle_fromSource, tf_angle_r, tf_angle_l, strcat(rootWorkingDirectory, staticC3d), Model2Use, ...
                    torsiontool, tib_torsion_RightMarkers, tib_torsion_LeftMarkers, ForceModelCreation, checkAndAdaptMomArms, sampleInput, ...
					useASTool, useDirectKinematics4TibRotEstimationAsFallback, useStatic4FrontAlignmentAsFallback, tibTorsionAdaptionMethod, InputData, pelvisWidthGenericModel, scalePelvisManually, varNameKneeAngle_c3d);

                % Add personalization info for fallback solutions
                % just for documentation here.
                SubjInfo.persInfoFromMarkers = persInfoFromMarkers;
				
				% Right info.
                % Add info about model personalization to InputData
                % logicals
                SubjInfo.UsedData4Personalization.r.Logicals.TF_adaption = char(tf_angle_fromSource_right);
                SubjInfo.UsedData4Personalization.r.Logicals.AV_adaption = char(torsionTool.femurAntetorsionAdaption);
                SubjInfo.UsedData4Personalization.r.Logicals.TT_adaption = char(torsionTool.tibTorsionAdaption);
                SubjInfo.UsedData4Personalization.r.Logicals.NS_adaption = char(torsionTool.neckShaftAdaption);
                SubjInfo.UsedData4Personalization.r.Logicals.TT_method = tibTorsionAdaptionMethod;
                SubjInfo.UsedData4Personalization.r.Logicals.MomArmsResolved = MomArmsResolved;

                % Values
                SubjInfo.UsedData4Personalization.r.Values.TF_angle = tf_angle_right;
                SubjInfo.UsedData4Personalization.r.Values.TT_angle = torsionTool.TTR;
                SubjInfo.UsedData4Personalization.r.Values.NS_angle = torsionTool.NSAR;
                SubjInfo.UsedData4Personalization.r.Values.AV_angle = torsionTool.AVR;

                % Left info.
                % Add info about model personalization to InputData
                % logicals
                SubjInfo.UsedData4Personalization.l.Logicals.TF_adaption = char(tf_angle_fromSource_left);
                SubjInfo.UsedData4Personalization.l.Logicals.AV_adaption = char(torsionTool.femurAntetorsionAdaption);
                SubjInfo.UsedData4Personalization.l.Logicals.TT_adaption = char(torsionTool.tibTorsionAdaption);
                SubjInfo.UsedData4Personalization.l.Logicals.NS_adaption = char(torsionTool.neckShaftAdaption);
                SubjInfo.UsedData4Personalization.l.Logicals.TT_method = tibTorsionAdaptionMethod;
                SubjInfo.UsedData4Personalization.l.Logicals.MomArmsResolved = MomArmsResolved;

                % Values
                SubjInfo.UsedData4Personalization.l.Values.TF_angle = tf_angle_left;
                SubjInfo.UsedData4Personalization.l.Values.TT_angle = torsionTool.TTL;
                SubjInfo.UsedData4Personalization.l.Values.NS_angle = torsionTool.NSAL;
                SubjInfo.UsedData4Personalization.l.Values.AV_angle = torsionTool.AVL;

                % Save Subject Info.
                save(strcat(workingDirectory,'Simulation\', char(strrep(sub_name,' ','_')),'-',condition,'-SubjInfo.mat'),'SubjInfo');

                % Set flag to know for next round that model was scaled already.
                flag_modelScaled = true;
            end

            % Create external loads file
            if tasks.ID
                path2extLoad = createExtLoadsFile(path2enf, path2mot, name, firstContact_L, firstContact_R);
            else
                path2extLoad = 'NaN';
            end

            % Run MODEL pipeline for left or right side or full trial.
            if strcmp(side, 'left')

                % Run the pipeline, each trial in one cmd window
                disp(char(strcat('>>>>> Started trial:',{' '},name, '_', side)));

                % Run simulation if everything is ready
                Model_workflow(workingDirectory, path2opensim, path2setupFiles, side, name, path2trc, path2mot, path2extLoad, path2Model, IC, cTO, cIC, TO, ICi, BW, cPrefix, tf_angle_r, tf_angle_l, labFlag, Model2Use,tasks);

            elseif strcmp(side, 'right')

                % Run the pipeline, each trial in one cmd window
                disp(char(strcat('>>>>> Started trial:',{' '}, name, '_', side)));

                % Run simulation if everything is ready
                Model_workflow(workingDirectory, path2opensim, path2setupFiles, side, name, path2trc, path2mot, path2extLoad, path2Model, IC, cTO, cIC, TO, ICi, BW, cPrefix, tf_angle_r, tf_angle_l, labFlag, Model2Use,tasks);
            
            else % Full trial processing

                % Run the pipeline, each trial in one cmd window
                disp(char(strcat('>>>>> Started trial:',{' '}, name, '_', side)));

                % Run simulation if everything is ready
                Model_workflow(workingDirectory, path2opensim, path2setupFiles, side, name, path2trc, path2mot, path2extLoad, path2Model, IC, cTO, cIC, TO, ICi, BW, cPrefix, tf_angle_r, tf_angle_l, labFlag, Model2Use,tasks);
            end

            %% Pause after maximum number of cmd windows are open
            proFilesCount = proFilesCount + 1;

            % Get processing time update
            tEnd = seconds(toc(tStart));
            tEnd.Format = 'hh:mm';

            % If max. number of files reached or all files from condition forwarded display message and wait for next batch.
            if i == length(trials) || getNCmdWindows() > maxCmd
                % Set the current number of processed files
                % Display status
                disp(' ');
                disp(' ');
                disp('*** Status Update ******************************************************************************************');
                disp(char(strcat('Current working directory:', {' '}, workingDirectory)));
                disp(char(strcat('Working directory',{' #'}, string(i_wd), {' '}, 'out of', {' #'}, string(length(workingDirectories)), '.')));
                disp(char(strcat('Current condition:', {' '}, condition, {' out of { '}, strjoin(conditions, ', '), ' }.')));
                disp(strcat('Total files to process in current WD:..................', num2str(length(trials))));
                disp(strcat('Processed files in current WD:.........................', num2str(proFilesCount)));
                disp(strcat('Files waiting to be processed in current WD:...........', num2str(length(trials)-i)));
                disp(strcat('Processing duration since <comak> start:',{' '}, string(tEnd),'(hh:mm).'));
                disp('************************************************************************************************************');
                disp(' ');

                % To potentially prevent buffer overflow, make sure to close all fids in case fids are still open
                fclose('all');

                % Wait until ...
				if useCPUThreshold				
					disp(strcat('-> Matlab paused! When CPU-load drops below the threshold of', {' '}, string(thresholdCpuLoad) ,{'% '},'the next batch of files will kick off ...'));
					CpuLoadBasedPausing_WIN11(thresholdCpuLoad, 60);
                else
					disp(strcat('-> Matlab paused! When the number of cmd windows drops below the threshold of N=', string(maxCmd) ,{' '},'of open cmd windows, the next batch of files will kick off ...'));
					monitorCmdWindowsAndWait(5, 8, maxCmd);
				end
            end
        end
    end

    % Update status in local WorkingDirectories file located in the
    % rootDirectory. Note that it is important to update and save the file
    % during each WD loop. In case of a Matlab crash otherwise all info
    % would be lost. 

    % For the parfor version of this script we need to save each time a
    % separate file, since otherwise Matlab might crash. The files will be
    % concatenated after the parfor loop is finished.

    % Create a directory to store the individual files
    outputDir = fullfile(rootDirectory, strcat('_', Model2Use, '-WD-tmpLogFiles')); % Note this path name is also hardcoded in startVarModels.m
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Define the header of the excel file.
    headers = {'Index', 'WorkingDirectories', 'Statics', 'Simulation', 'Processed', 'ModelWOadaption'};
    
    % Create a table with the data
    data = table(i_wd, string(workingDirectories{i_wd}), string(staticC3d), 1, NaN, string(MomArmsResolved), 'VariableNames', headers);
    
    % Use parfor to create individual files
    wdFile = fullfile(outputDir, sprintf('parforLoop_%d.xlsx', i_wd)); % Note this file name is also hardcoded in cleanUpParforWDFiles.m
    writetable(data, wdFile);

    % End timer
    tEnd = seconds(toc(tStart));
    tEnd.Format = 'hh:mm';
    disp(''); % new line
    disp('************************************************************************************************************');
    disp(strcat('>>>>>  Total processing duration:',{' '}, string(tEnd),'(hh:mm). <<<<<'));

end
end
