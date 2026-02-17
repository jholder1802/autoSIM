function [path2scaledModel, tf_angle_out, torsionTool_out, tf_angle_fromSource_out, MomArmsResolved] = prepareScaledModel(rootWorkingDirectory, workingDirectory, path2GenericModels, ...
    path2bin, path2opensim, bodymass, static_trc_fileName, side, ...
    labFlag, lockSubtalar4Scaling, scaleMuscleStrength, manualMusScaleF, ...
    prefix, bodyheightGenericModel, BodyHeight, ...
    tf_angle_manual, tf_angle_fromSource, path2static, torsiontool, ...
    tib_torsion_Markers, ForceModelCreation, checkAndAdaptMomArms, sampleInputFile, useASTool, useDirectKinematics4TibRotEstimationAsFallback, ...
    InputData, scalePelvisManually, pelvisWidthGenericModel, useStatic4FrontAlignmentAsFallback, tibTorsionAdaptionMethod, varNameKneeAngle_c3d)

% This file scales the *.osim model using the API and opensim from the
% comak bin folder. Additionally it also scales the contact geometry by
% using the scale factors from the femur, tibia, patella. Contact
% geometries are not scaled duirng the comak workflow automatically.
%

% Written by:           Brian Horsak - brian.horsak@fhstp.ac.at
% Acknowledgements:     Many thx to Bryce Killian (KU Leuven) for his great
%                       support
%
% Last changed:         09/2025
% -------------------------------------------------------------------------


%% Gather all necessary information

% Create lab specific vars
% NOTE: to add a new lab you will only need to add it to the switch
% statement. No furtehr changes to the code should be necessary here. 

switch labFlag

    case 'ISW'
        markerSetPath = 'ISW\ISW_MarkerSet_COMAK.xml';
        path2ScaleFile = char(fullfile(path2GenericModels,'ISW\'));
        model_right  = 'COMAK_FullBodyRight';
        model_left =  'COMAK_FullBodyLeft';
        scaleTemplate = 'ISW_comakScaling'; % e.g. comakScalingLeft.xml

    case {'OSS', 'FHSTP-BIZ', 'FHSTP'}
        markerSetPath = 'OSS_FHSTP\OSS_Clevland_MarkerSet_COMAK.xml';
        path2ScaleFile = char(fullfile(path2GenericModels,'OSS_FHSTP\'));
        model_right  = 'COMAK_FullBodyRight';
        model_left =  'COMAK_FullBodyLeft';
        scaleTemplate = 'OSS_comakScaling'; % e.g. comakScalingLeft.xml

    case {'OSSnoArms', 'FHSTPnoArms'}
        markerSetPath = 'OSS_FHSTPnoArms\OSSnoArms_Clevland_MarkerSet_COMAK.xml';
        path2ScaleFile = char(fullfile(path2GenericModels,'OSS_FHSTPnoArms\'));
        model_right  = 'COMAK_FullBody-noArmsRight';
        model_left =  'COMAK_FullBody-noArmsLeft';
        scaleTemplate = 'OSSnoArms_comakScaling'; % e.g. comakScalingLeft.xml

    case 'LKHG_Cleve'
        markerSetPath = 'LKHG_Cleve\LKHG_Cleveland_MarkerSet_COMAK.xml';
        path2ScaleFile = char(fullfile(path2GenericModels,'LKHG_Cleve\'));
        model_right  = 'COMAK_FullBodyRight';
        model_left =  'COMAK_FullBodyLeft';
        scaleTemplate = 'LKHG_Cleve_comakScaling'; % e.g. comakScalingLeft.xml

    case 'LKHG_PiG'
        markerSetPath = 'LKHG_PiG\PiG_LowerBody_MarkerSet_COMAK.xml';
        path2ScaleFile = char(fullfile(path2GenericModels,'LKHG_PiG\'));
        model_right  = 'COMAK_FullBodyRight';
        model_left =  'COMAK_FullBodyLeft';
        scaleTemplate = 'LKHG_PiG_comakScaling'; % e.g. comakScalingLeft.xml

    case 'PLUS_COD_noArms'
        markerSetPath = '_PLUS_COD_noArms\PLUS_COD_noArms_MarkerSet_COMAK.xml';
        path2ScaleFile = char(fullfile(path2GenericModels,'_PLUS_COD_noArms\'));
        model_right  = 'COMAK_FullBody-noArmsRight';
        model_left =  'COMAK_FullBody-noArmsLeft';
        scaleTemplate = 'PLUS_COD_noArms_comakScaling'; % e.g. comakScalingLeft.xml

    case {'PLUS_SportsMarkerset_noArms','PLUS_SportsMarkerset_noArms_newFPs'}
        markerSetPath = '_PLUS_pilotMC_noArms\PLUS_pilotMC_SportsMarkerset_noArms.xml';
        path2ScaleFile = char(fullfile(path2GenericModels,'_PLUS_pilotMC_noArms\'));
        model_right  = 'COMAK_FullBody-noArmsRight_26052025'; % % 'COMAK_FullBody-noArmsRight-lig5','COMAK_FullBody-noArmsRight-lig5_sgfKneeInd'
        model_left =  'COMAK_FullBody-noArmsLeft_26052025'; % % 'COMAK_FullBody-noArmsLeft-lig5','COMAK_FullBody-noArmsLeft-lig5_sgfKneeInd'
        scaleTemplate = 'PLUS_pilotMC_noArmsScaling'; % e.g. comakScalingLeft.xml
end

% Check if vars exist. If not raise error.
variables = {'markerSetPath', 'path2ScaleFile', 'scaleTemplate'}; % List of variable names

for i = 1:length(variables)
    if ~exist(variables{i}, 'var')
        error('The markerset seems not to be implemented yet! See prepareScaledModel function.');
    end
end

% Define file paths
path.genModels = char(fullfile(path2GenericModels));
path.workingDirectory = char(workingDirectory);
path.scaleFile = char(path2ScaleFile);
% path.static = strcat(rootWorkingDirectory, static_trc_fileName);
path.static = char(static_trc_fileName);
path.markerSet = strcat(path.genModels, markerSetPath);
path.geometry = strcat(workingDirectory, 'Geometry\');
path.bin = path2bin;
path.plugIn = fullfile(path2bin, 'jam_plugin.dll');
path.opensim = path2opensim;
trialInfo.side = char(lower(side(1)));
trialInfo.BM = bodymass;

% Get start and stop time of static file
trc = read_trcFile(char(path.static));
startTime = trc.Data(2,2);
stopTime = trc.Data(15,2);  % take only the first 15 frames to speed up the total process.

%% Some houesekeeping variables

% Define which model/templates to use
if strcmp(trialInfo.side, 'r')
    usedModel = model_right;
    scaleTemplate = strcat(scaleTemplate,'Right.xml');
elseif strcmp(trialInfo.side, 'l')
    usedModel = model_left;
    scaleTemplate = strcat(scaleTemplate,'Left.xml');
end

% Define left/right contact geometries
% Note the bone files are scaled because for plotting they need to be
% scaled. During comak however, it seems as if they are scaled
% automatically.
if strcmp(trialInfo.side, 'r')
    femCart = 'lenhart2015-R-femur-cartilage.stl';
    tibCart = 'lenhart2015-R-tibia-cartilage.stl';
    patCart = 'lenhart2015-R-patella-cartilage.stl';
    femBone = 'lenhart2015-R-femur-bone.stl';
    tibBone = 'lenhart2015-R-tibia-bone.stl';
    patBone = 'lenhart2015-R-patella-bone.stl';

elseif strcmp(trialInfo.side, 'l')
    femCart = 'lenhart2015-R-femur-cartilage_mirror.stl';
    tibCart = 'lenhart2015-R-tibia-cartilage_mirror.stl';
    patCart = 'lenhart2015-R-patella-cartilage_mirror.stl';
    femBone = 'lenhart2015-R-femur-bone_mirror.stl';
    tibBone = 'lenhart2015-R-tibia-bone_mirror.stl';
    patBone = 'lenhart2015-R-patella-bone_mirror.stl';
end

%% Check if model already exists
% Change to working directory
cd(workingDirectory);

% Look for *.osim files in folder
ls = dir('*scaled*.osim');
modelNames = {ls.name};

% Check if used Model exists & if user wants to use it
if ~ForceModelCreation && sum(contains(modelNames, usedModel)) > 0

    % Info to user
    disp(char(strcat('>>>>> An existing model was found and user did not force model creation. No new models created!')));

    % Set path to found model
    modelNames = modelNames(contains(modelNames, usedModel));
    if any(contains(modelNames,'WO')) % % % adapted (jh, 24.04.): Wrapping Objects (WO) were adapted, using this model
        idxModel = find(and(~contains(modelNames,'only4ID'),contains(modelNames,'WO')));
    else
        idxModel = find(~contains(modelNames,'only4ID')); % get the model used for COMAK not the one without the forceset for Inverse Dynamics.
    end

    if size(idxModel,2) > 1
        % Raise error if more than one model was found.
        error('>>>>> More than one potential model found for processing.')
    end

    % Set model path
    path2scaledModel = fullfile(path.workingDirectory,modelNames{idxModel});

else
    %% Prepare scaling in OpenSim API

    % Copy model to working directory
    path.genModel = strcat(path.genModels, usedModel,'.osim');
    path.genModel4Scaling = fullfile(path.workingDirectory,strcat(usedModel,'.osim'));
    copyfile(path.genModel, path.genModel4Scaling);

    %% Change generic model in working directory and lock subtalar, MTP for scaling.
    if lockSubtalar4Scaling

        % Load model
        modelFile = fullfile(path.genModel4Scaling);

        % Adapt model if selected, e.g. lock MTP,
        lockUnlockJoint(modelFile, path.plugIn, 'subtalar_r', 'lock', 0);
        lockUnlockJoint(modelFile, path.plugIn, 'subtalar_l', 'lock', 0);
    end

    % Check if we want to scale the pelvis "manually" - then we need to use the
    % _PelvisManual" version of the scaleTemplate file.

    % Get Pelvis Size from first trial
    fn = fieldnames(InputData);
    hipdWidth = InputData.(fn{1}).HipWidth;

    if scalePelvisManually && ~isnan(hipdWidth)
        scaleTemplate = [scaleTemplate(1:end-4), '_PelvisManualScaling.xml'];
    end

    % Copy scale setting file to working directory
    path.scaling = char(strcat(path.workingDirectory,'Scaling\'));

    if ~logical(exist(path.scaling, 'dir'))
        mkdir(path.scaling);
    end

    copyfile(strcat(path.scaleFile, scaleTemplate), path.scaling);

    %% If we selected to scale the pelvis manually, now change scale value to actual one.

    if scalePelvisManually && ~isnan(hipdWidth)

        % Calculate ratio
        scaleValue = hipdWidth / pelvisWidthGenericModel;

        % Change value
        xml_file = fullfile(char(strcat(path.workingDirectory,'Scaling\')), scaleTemplate);
        changeXML(xml_file,'scales', char([' ' num2str(scaleValue) ' ' num2str(scaleValue) ' ' num2str(scaleValue) ' ']),1);
    end

    %% Adjust Model torsion

    % Use TorsionTool: Adapt femur anteversion, tibia torsion and neckshaft angle using the torsionTool and the ModelPersonalizationInfo file in the WD.

    % Read model personalization info
    dataFile = fullfile(rootWorkingDirectory, 'data.xml');
    if isfile(dataFile)
        persInfo = readstruct(dataFile);

        % Check if the personalization data in persInfo can be used based on
        % the examination date. Otherwise skip. The difference should be below 30
        % days for TT.
        TorsionOk = checkIfExternalDataIsValid(persInfo, 'MRICTdate', 'EXAMINATIONdate', 30);
    else
        persInfo = ''; % just to have the variable.
        TorsionOk = false;
    end

    if (torsiontool.tibTorsionAdaption || torsiontool.neckShaftAdaption || torsiontool.femurAntetorsionAdaption) && TorsionOk
        % Use the Torsion tool with the external data file info (TT, AV, NSA)
        % In case the torisontool will not find any information for TT, AV, or NSA in the dataFile it will skip that specific personalization step.

        % Copy Markerset for adjustments to the scaling settings folder and get markerset name
        copyfile(path.markerSet, [workingDirectory,'Scaling\',]);
        nameMarkerSetFile = markerSetPath;
        match = wildcardPattern + '\';
        nameMarkerSetFile = erase(nameMarkerSetFile,match);
        path.markerSet = [workingDirectory,'Scaling\',nameMarkerSetFile];

        % Start TorsionTool
        disp('>>>>> TorsionTool started ...');
        [path.genModel4Scaling, path.markerSet4Scaling, torsionTool_out] = TorsionToolAllModels(torsiontool, persInfo, path, path.genModel4Scaling, rootWorkingDirectory, workingDirectory, side);


    elseif (torsiontool.tibTorsionAdaption || torsiontool.neckShaftAdaption || torsiontool.femurAntetorsionAdaption) && strcmp(tibTorsionAdaptionMethod, 'fromStatic')
        % Use the Torsion tool with the direct kinematic info from the c3d static model outputs (only for TT)!
        % In case the torisontool will not find any information for TT it will skip that specific personalization step.

        % Copy Markerset for adjustments to the scaling settings folder and get markerset name
        copyfile(path.markerSet, [workingDirectory,'Scaling\',]);
        nameMarkerSetFile = markerSetPath;
        match = wildcardPattern + '\';
        nameMarkerSetFile = erase(nameMarkerSetFile,match);
        path.markerSet = [workingDirectory,'Scaling\',nameMarkerSetFile];

        % Initialize new personalization infos.
        persInfo4TTfromStaticOnly = persInfo;
        persInfo4TTfromStaticOnly.TTR_degree = round(getTTangleFromDirKinemStatic(path2static, InputData, 'r', varNameKneeAngle_c3d));
        persInfo4TTfromStaticOnly.TTL_degree = round(getTTangleFromDirKinemStatic(path2static, InputData, 'r', varNameKneeAngle_c3d));

        torsiontool4TTfromStaticOnly = torsiontool;
        torsiontool4TTfromStaticOnly.femurAntetorsionAdaption = false; % just to make sure the values are not rotated again in case they were.
        torsiontool4TTfromStaticOnly.neckShaftAdaption = false; % just to make sure the values are not rotated again in case they were.

        % Start TorsionTool
        disp('>>>>> TorsionTool started ...');
        [path.genModel4Scaling, path.markerSet4Scaling, torsionTool_out] = TorsionToolAllModels(torsiontool4TTfromStaticOnly, persInfo4TTfromStaticOnly, path, path.genModel4Scaling, rootWorkingDirectory, workingDirectory, side);

    else
        % Run standard tool - User decided to not use the TorsionTool for any adjustments OR dataFile was not available.
        % The following lines of code only specify NaNs for the model adjustment info since we alwaqys have to initialize the variables.

        % Set standard paths
        path.markerSet4Scaling = path.markerSet;

        % Store adaption settings.
        torsionTool_out.(strcat('tibTorsionAdaption_',lower(side(1)))) = mat2str(torsiontool.tibTorsionAdaption);
        torsionTool_out.(strcat('femurAntetorsionAdaption_',lower(side(1)))) = mat2str(torsiontool.femurAntetorsionAdaption);
        torsionTool_out.(strcat('neckShaftAdaption_',lower(side(1)))) = mat2str(torsiontool.neckShaftAdaption);

        % Initialize output values to standard values when they are not used/changed.
        torsionTool_out.AVR = NaN;
        torsionTool_out.AVL = NaN;
        torsionTool_out.NSAR = NaN;
        torsionTool_out.NSAL = NaN;
        torsionTool_out.TTR = NaN;
        torsionTool_out.TTL = NaN;

        % In case we intended to use the Torsiontool tell user that we skipped it because the data file containing the personalization info was missing or wrong.
        if (torsiontool.tibTorsionAdaption || torsiontool.neckShaftAdaption || torsiontool.femurAntetorsionAdaption) && ~TorsionOk
            warning('Model personalization file in WD for torsion tool was either not found or data Examination date and MRI-CT date were too far apart. TorsionTool skipped.');
        end
    end

    % In case user decided to change the TT using the external dataFile BUT either the file was not available
    % OR the value in the file was NaN this will be the fallback solution.
    if useDirectKinematics4TibRotEstimationAsFallback && ~strcmp(tibTorsionAdaptionMethod, 'fromStatic')
        if torsiontool.tibTorsionAdaption && ~TorsionOk || torsiontool.tibTorsionAdaption && isnan(persInfo.TTR_degree) && isnan(persInfo.TTL_degree) % note that here the fallback only applies when both TTL and TTR are NaN. In case only one is NaN it won`t work.

            % Specify the TT value using the data from the static trial and the markers specified in <start.m>.
            acq = btkReadAcquisition(path2static);
            btkCloseAcquisition(acq);

            % Initialize new personalization infos.
            persInfo4TTfromStaticOnly = persInfo;

            % Set new personalization infos.
            persInfo4TTfromStaticOnly.TTR_degree = round(getTTangleFromDirKinemStatic(path2static, InputData, 'r', varNameKneeAngle_c3d));
            persInfo4TTfromStaticOnly.TTL_degree = round(getTTangleFromDirKinemStatic(path2static, InputData, 'l', varNameKneeAngle_c3d));

            torsiontool4TTfromStaticOnly = torsiontool;
            torsiontool4TTfromStaticOnly.femurAntetorsionAdaption = false; % just to make sure the values are not rotated again in case they were.
            torsiontool4TTfromStaticOnly.neckShaftAdaption = false; % just to make sure the values are not rotated again in case they were.

            % Start TorsionTool
            warning('>>>>> TorsionTool (fallback-solution) started ONLY for TibialTorsion using the torsion information derived from the static trial ...');
            [path.genModel4Scaling, path.markerSet4Scaling, torsionTool_out] = TorsionToolAllModels(torsiontool4TTfromStaticOnly, persInfo4TTfromStaticOnly, path, path.genModel4Scaling, rootWorkingDirectory, workingDirectory, side);
        end
    end

    %% Adapt frontal tibio-femoral angles in models before scaling (if tf_angle is ~= 0)

    % Set side-specific variable.
    if strcmpi(side(1), 'l')
        varNameKneeAngle_c3d_2use = varNameKneeAngle_c3d.L;
    elseif strcmpi(side(1), 'r')
        varNameKneeAngle_c3d_2use = varNameKneeAngle_c3d.R;
    else
        error('>>>> Side not properly defined!')
    end

    [path.genModel4Scaling, tf_angle_out, tf_angle_fromSource_out] = adjustFrontAlignmentModel(path.genModel4Scaling, path.plugIn, tf_angle_manual, side, tf_angle_fromSource, path2static, BodyHeight, bodymass, persInfo, ...
                                                                    useStatic4FrontAlignmentAsFallback, rootWorkingDirectory, varNameKneeAngle_c3d_2use, varNameKneeAngle_c3d.posFront);

    %% Load OpenSim API and scale the model
    % Load the API, and jam plugin
    import org.opensim.modeling.*
    opensimCommon.LoadOpenSimLibrary(path.plugIn);

    %% Change generic model in working directory and lock the knee and patella dof for translation.
    % Otherwise the scaling will mess up the joint configuration. In
    % addition the marker placer will replace the tight and shank markers to
    % wrong places. This will results in errors and higher IK errors.

    % Load model
    model = Model(path.genModel4Scaling);

    % change the dofs for the patella
    pfJoint = model.get_JointSet().get(strcat('pf_',trialInfo.side));
    pf_sag = pfJoint.upd_coordinates(0);
    pf_front = pfJoint.upd_coordinates(1);
    pf_trans = pfJoint.upd_coordinates(2);
    pf_tx = pfJoint.upd_coordinates(3);
    pf_ty = pfJoint.upd_coordinates(4);
    pf_tz = pfJoint.upd_coordinates(5);

    pf_sag.set_locked(true);
    pf_front.set_locked(true);
    pf_trans.set_locked(true);
    pf_tx.set_locked(true);
    pf_ty.set_locked(true);
    pf_tz.set_locked(true);

    % change the dofs for the knee
    KneeJoint = model.get_JointSet().get(strcat('knee_',trialInfo.side));
    knee_add = KneeJoint.upd_coordinates(1);
    knee_rot = KneeJoint.upd_coordinates(2);
    knee_tx = KneeJoint.upd_coordinates(3);
    knee_ty = KneeJoint.upd_coordinates(4);
    knee_tz = KneeJoint.upd_coordinates(5);

    knee_add.set_locked(true);
    knee_rot.set_locked(true);
    knee_tx.set_locked(true);
    knee_ty.set_locked(true);
    knee_tz.set_locked(true);

    % Save model
    path.genModelLocked4Scaling = strcat(path.genModel4Scaling(1:end-5), '_locked4Scaling.osim');
    model.print(path.genModelLocked4Scaling);

    switch useASTool
        case true
            disp('>>>>> User decided to use the Automatic Scaling Tool (AST).')

            %% Change xml ScaleSettings file
            xml_file = fullfile(path.scaling, scaleTemplate);
            [~,name,ext] = fileparts(path.static);
            staticFile = [name,ext]; % Fot AST we only need the file name.
            changeXML(xml_file,'mass',char(num2str(trialInfo.BM)),1);
            changeXML(xml_file,'model_file', 'Unassigned', 1); % needs to be "Unassigned" for all tasks in the setup file for AST.
            changeXML(xml_file,'marker_set_file', 'Unassigned', 1); %marker set
            changeXML(xml_file,'marker_file', staticFile, 2); % 2 -> change twice, also for second node in marker placer
            changeXML(xml_file,'time_range',num2str([startTime stopTime]), 2); % 2 -> change twice, also for second node in marker placer
            changeXML(xml_file,'output_model_file','Unassigned', 2); % 2 -> change twice

            scaleFactorFile = char(strcat(path.workingDirectory,'Scaling\',usedModel,'-AST_ScaleFactors.xml'));
            changeXML(xml_file,'output_scale_file', scaleFactorFile, 1);
            changeXML(xml_file,'output_motion_file','Unassigned', 1);

            % Prepare the input for the AST tool.
            path2BaseModel = path.genModelLocked4Scaling;
            path2trc = path.static;
            path2SetUpFile = xml_file;
            workingDir4AST = fullfile(path.scaling, strcat('ASTool-',side));

            % Attach markerset to model in case it is not attached.
            modelTmp = Model(path.genModelLocked4Scaling);
            if modelTmp.getMarkerSet().getSize() == 0

                markerSet = MarkerSet(path.markerSet4Scaling);
                % Add each marker from the marker set to the model
                for i = 0 : markerSet.getSize()-1
                    marker = markerSet.get(i);
                    modelTmp.addMarker(marker);
                end
                state = modelTmp.initSystem();
                modelTmp.print(path.genModelLocked4Scaling);
            end

            % Get total body mass from generic model.
            modelTmp = Model(path.genModelLocked4Scaling);
            state = modelTmp.initSystem();
            TotalBodyMassGenModel = modelTmp.getTotalMass(state);

            % Set model geometry search path.
            ModelVisualizer.addDirToGeometrySearchPaths(path.geometry);
            state = modelTmp.initSystem();
            modelTmp.print(path.genModelLocked4Scaling);

            % Input data for model and subject mass and height for initial scaling.
            modelData.SubjectHeight = BodyHeight/10;                        % Height of generic model (cm). Note the conversion from mm to cm!
            modelData.SubjectWeight = trialInfo.BM;                         % Weight of subject (Kg)
            modelData.GenericModelHeight = bodyheightGenericModel/10;       % Height of generic model (cm). Note the conversion from mm to cm!
            modelData.GenericModelWeight = TotalBodyMassGenModel;           % Total Body Mass generic model.

            % Set last AST inputs.
            trcScale = 1; % default = 1 for COMAK workfow. For trc files in mm 1000 for trc files in m 1.
            setPose = 1;  % 1 = recommended by AST.

            % Now call the AST tool.
            ASTmodel = ASTool(path2BaseModel, path2trc, path2SetUpFile, workingDir4AST, modelData, setPose, path.plugIn, trcScale);

            % Now copy the model out of the AST folder back to Working Directory.
            [~,name,~] = fileparts(path.genModelLocked4Scaling); % Make scaled model name
            path2scaledModel = strcat(workingDirectory,name(1:end-15),'-ASTscaled.osim');
            copyfile(ASTmodel, path2scaledModel);

        case false
            %% Change xml ScaleSettings file
            xml_file = strcat(path.scaling, scaleTemplate);
            changeXML(xml_file,'mass',char(num2str(trialInfo.BM)),1);
            changeXML(xml_file,'model_file', path.genModelLocked4Scaling,1); % use the locked model!
            changeXML(xml_file,'marker_set_file', path.markerSet4Scaling,1); %marker set
            changeXML(xml_file,'marker_file',path.static,2); % 2 -> change twice, also for second node in marker placer
            changeXML(xml_file,'time_range',num2str([startTime stopTime]),2); % 2 -> change twice, also for second node in marker placer

            [~,name,~] = fileparts(path.genModelLocked4Scaling); % Make scaled model name
            path2scaledModel = strcat(workingDirectory,name(1:end-15),'-scaled.osim');
            changeXML(xml_file,'output_model_file',' ' ,1); % keep empty because otherwise I need to unlock the joints as well and would also need to scale the contact geometry!
            changeXML(xml_file,'output_model_file',path2scaledModel,2,2); % change second node only
            scaleFactorFile = char(strcat(path.workingDirectory,'Scaling\',usedModel,'-ScaleFactors.xml'));
            changeXML(xml_file,'output_scale_file',scaleFactorFile,1);
            changeXML(xml_file,'output_motion_file',char(strcat(path.workingDirectory,'Scaling\',usedModel,'-Static.mot')),1);

            %% Run OpenSim Scaling in Matlab Window (this ensures that matlab will proceed only when scaling is finished)

            [~,out] = system(char(strcat(path.opensim ,'opensim-cmd -L',{' '}, path.plugIn,{' '}, 'run-tool',{' '}, xml_file)),'-echo');

            % Write Scaling log to text file
            txt = strcat(path.scaling,'ScalingLog_',trialInfo.side,'.txt');
            fid = fopen(txt,'wt');
            fprintf(fid, '%s\n%s\n', out);
            fclose(fid);

    end

    %% Unlock the dofs for the scaled model
    % Load model
    model = Model(path2scaledModel);

    % change the dofs for the patella
    pfJoint = model.get_JointSet().get(strcat('pf_',trialInfo.side));
    pf_sag = pfJoint.upd_coordinates(0);
    pf_front = pfJoint.upd_coordinates(1);
    pf_trans = pfJoint.upd_coordinates(2);
    pf_tx = pfJoint.upd_coordinates(3);
    pf_ty = pfJoint.upd_coordinates(4);
    pf_tz = pfJoint.upd_coordinates(5);

    pf_sag.set_locked(false);
    pf_front.set_locked(false);
    pf_trans.set_locked(false);
    pf_tx.set_locked(false);
    pf_ty.set_locked(false);
    pf_tz.set_locked(false);

    % change the dofs for the knee
    KneeJoint = model.get_JointSet().get(strcat('knee_',trialInfo.side));
    knee_add = KneeJoint.upd_coordinates(1);
    knee_rot = KneeJoint.upd_coordinates(2);
    knee_tx = KneeJoint.upd_coordinates(3);
    knee_ty = KneeJoint.upd_coordinates(4);
    knee_tz = KneeJoint.upd_coordinates(5);

    knee_add.set_locked(false);
    knee_rot.set_locked(false);
    knee_tx.set_locked(false);
    knee_ty.set_locked(false);
    knee_tz.set_locked(false);

    % Save model
    model.print(path2scaledModel);

    %% Undo the locking
    if lockSubtalar4Scaling
        % Load model
        modelFile = fullfile(path2scaledModel);

        % Adapt model if selected, e.g. lock MTP,
        lockUnlockJoint(modelFile, path.plugIn, 'subtalar_r', 'unlock', 0);
        lockUnlockJoint(modelFile, path.plugIn, 'subtalar_l', 'unlock', 0);
    end

    %% Load scale factors and scale contact geometry
    sf_tree = xml2struct(scaleFactorFile);

    % Now find the femur, patella, and tibia scale factors
    for i = 1 : size(sf_tree.OpenSimDocument.ScaleSet.objects.Scale,2)
        fnames{1,i} = sf_tree.OpenSimDocument.ScaleSet.objects.Scale{1, i}.segment.Text;
    end

    % Find index where bodys are stored
    fem_idx = find(ismember(fnames,strcat('femur_',trialInfo.side)));
    tib_idx = find(ismember(fnames,strcat('tibia_',trialInfo.side)));
    pat_idx = find(ismember(fnames,strcat('patella_',trialInfo.side)));

    % Extract scale factors
    sf_fem = str2num(sf_tree.OpenSimDocument.ScaleSet.objects.Scale{1, fem_idx}.scales.Text);
    sf_tib = str2num(sf_tree.OpenSimDocument.ScaleSet.objects.Scale{1, tib_idx}.scales.Text);
    sf_pat = str2num(sf_tree.OpenSimDocument.ScaleSet.objects.Scale{1, pat_idx}.scales.Text);

    % Scale contact cartilage and rename
    scaleMesh(strcat(path.geometry,femCart),sf_fem(1),sf_fem(2),sf_fem(3), 'True');
    scaleMesh(strcat(path.geometry,tibCart),sf_tib(1),sf_tib(2),sf_tib(3), 'True');
    scaleMesh(strcat(path.geometry,patCart),sf_pat(1),sf_pat(2),sf_pat(3), 'True');

    % Scale bone and rename
    scaleMesh(strcat(path.geometry,femBone),sf_fem(1),sf_fem(2),sf_fem(3), 'True');
    scaleMesh(strcat(path.geometry,tibBone),sf_tib(1),sf_tib(2),sf_tib(3), 'True');
    scaleMesh(strcat(path.geometry,patBone),sf_pat(1),sf_pat(2),sf_pat(3), 'True');

    % EXTRA dirty hack to change *.stl files, because the API does not seem to offer
    % the possability. 'PropertyStr' seems not to exist in the Matlab API ...

    % Thx for Willi Koller for his support!
    % Read final model file
    fid  = fopen(path2scaledModel,'r');
    f = fread(fid,'*char')';
    fclose(fid);

    % Change *.stl files manually
    meshFile = {femCart; tibCart; patCart; femBone; tibBone; patBone};
    fid  = fopen(path2scaledModel,'w');

    % Find line where the contact geometry starts. I will just change the
    % xml file starting from here so that the other <mesh_file> nodes e.g.
    % in <BodySet name="bodyset"> are not changed!
    idx = strfind(f,'<ContactGeometrySet name="contactgeometryset">');

    % Now change the relevant *.stl file nodes
    fpart = f(idx:end);
    for j = 1:6
        fpart = strrep(fpart ,meshFile{j},strcat(meshFile{j}(1:end-4),'_scaled.stl'));
    end
    % Save the model.
    fprintf(fid,'%s',strcat(f(1:idx),fpart(2:end)));
    fclose(fid);

    %% Change translation of patella directly in osim model using the API

    % Load model
    model = Model(path2scaledModel);

    % Get scale factors
    patBody = model.get_BodySet.get(strcat('patella_',trialInfo.side));
    patScalesOS = patBody.get_attached_geometry(0).get_scale_factors();
    if ~strcmp(patBody.get_attached_geometry(0), 'patella_bone'); disp('>>>>> Wrong body selected in API during scaling  '); return; end

    % Get joint set
    JointSet = model.get_JointSet();
    JointSet.get(strcat('pf_',trialInfo.side));
    pfJoint = model.get_JointSet().get(strcat('pf_',trialInfo.side));
    pfFrame = pfJoint.get_frames(0); % there is only one frame in that node

    % Extract values from osim object
    for i = 1:3
        patScales(i) = patScalesOS.get(i-1); % The API indexing starts at 0!
    end

    % Change pft, new patelle translation = old pt * sf - oldpt
    if strcmp(trialInfo.side, 'r')
        x = 0.053 * patScales(1) - 0.053;
        y = 0.005 * patScales(2) - 0.005;
        z = 0.004 * patScales(3) - 0.004;
    elseif strcmp(trialInfo.side, 'l')
        x = 0.053 * patScales(1) - 0.053;
        y = 0.005 * patScales(2) - 0.005;
        z = (-0.004 * patScales(3) - -0.004) - 0.008;
    end

    % Create osim vector
    pft = ArrayDouble.createVec3([x,y,z]);

    % Define new pt in model component
    pfFrame.set_translation(pft);

    % Save model
    model.print(path2scaledModel);

    %% Scale the muscle max isometric force
    scaleMuscleStrength = lower(scaleMuscleStrength);
    switch scaleMuscleStrength
        case 'no'
            disp('>>>>> Muscle strength of model will not be adjusted!')

        case 'manually'
            disp(['>>>>> Muscle strength of model scaled by manual value of <',num2str(manualMusScaleF),'>!'])
            path2scaledModelwithStrength = strcat(path2scaledModel(1:end-5),'-Msl.osim');
            strengthScaler(manualMusScaleF, path.plugIn, path2scaledModel, path2scaledModelwithStrength);
            path2scaledModel = path2scaledModelwithStrength;

        case {'height2pow2', 'height2pow3'} % see paper “How much muscle strength is required to walk in a crouch gait?”  https://doi.org/10.1016/j.jbiomech.2012.07.028

            if strcmp(scaleMuscleStrength, 'height2pow2')
                Power = 2;
            elseif strcmp(scaleMuscleStrength, 'height2pow3')
                Power = 3;
            end

            ScaleF = (BodyHeight / bodyheightGenericModel)^Power;

            disp(['>>>>> Muscle strength of model scaled by "HeightSquared Method" <',num2str(ScaleF),'>!']);
            path2scaledModelwithStrength = strcat(path2scaledModel(1:end-5),'-Msl.osim');
            strengthScaler(ScaleF, path.plugIn, path2scaledModel, path2scaledModelwithStrength);
            path2scaledModel = path2scaledModelwithStrength;
    end

    %% Clean saved models

    % Change to working directory
    cd(workingDirectory);

    % Delete all unecessary models
    files2delete = dir(fullfile(path.workingDirectory, '*.osim')); % find all relevant *.osim files
    files2delete = {files2delete(:).name};
    [~,tmpName,~] = fileparts(path2scaledModel); % name of the final *.osim file
    idx1 = find(contains(files2delete,strcat(tmpName,'.osim'))); % idx of the final file which should not be deleted
    idx2 = find(~contains(files2delete,usedModel)); % remove all files from list2delete that are not from current loop, otherwise existing models of the other side will be deleted.
    idx = [idx1, idx2];
    files2delete(idx) = []; % remove the final *.osim file from list
    delete(files2delete{:});

    % Now delete all models without COMAK in its name to get rid of the TorsionTool leftovers
    files2delete = dir(fullfile(path.workingDirectory, 'tmpTorsionTool*.osim')); % find all relevant *.osim files
    if ~isempty(files2delete)
        files2delete = {files2delete(:).name};
        delete(files2delete{:});
    end

    %% Check for muscle moment arm discontinuities and try to resolve.
    if checkAndAdaptMomArms
        path2PlugIn = path.plugIn;
        setupFile = fullfile(path.scaleFile, 'simpleIKsettings2checkMomArms.xml');

        % Try to run IK. We need IK to run the muscle moment check tool.
        [resultsAreValid, IK_results_OutputPath] = runSimpleIKTask(setupFile, path2scaledModel, sampleInputFile, fullfile(path.workingDirectory), path2PlugIn);

        % IF IK was successfull check for muscle moment arm discontinuities.
        if resultsAreValid
            [MomArmsResolved, path2scaledModel] = adaptWrappingObjectsToCorrectMuscleMomentArms(path2scaledModel, IK_results_OutputPath, path2PlugIn);
        else
            MomArmsResolved = 'IK not successful to allow for checking momentarms';
        end

        % Delete unnecessary file.
        delete(IK_results_OutputPath);
    else
        MomArmsResolved = 'User did not select to check for muscle momentarm discontinuities.';
    end

    %% Display finished message
    [~,name,ext] = fileparts(path2scaledModel);
    disp([newline char(strcat('>>>>> Scaling of model and contact geometry done for:', {' '}, [name,ext])) newline]);
end

%% Clear variables except output to prevet memory leak.
clearvars -except path2scaledModel tf_angle_out torsionTool_out tf_angle_fromSource_out MomArmsResolved
end