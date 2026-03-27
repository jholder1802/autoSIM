function [path2scaledModel, torsionTool_out, tf_angle_fromSource_r, tf_angle_fromSource_l, tf_angle_right, tf_angle_left, MomArmsResolved, persInfoFromMarkers] = prepareScaledModel(rootWorkingDirectory, workingDirectory, path2GenericModels, path2opensim, bodymass, static_trc_fileName, ...
    labFlag, lockSubtalar4Scaling, scaleMuscleStrength, manualMusScaleF, prefix, bodyheightGenericModel, BodyHeight, ...
    tf_angle_fromSource, tf_angle_r, tf_angle_l, staticC3d, Model2Use, torsiontool, tib_torsion_Markers_Right, tib_torsion_Markers_Left, ...
    ForceModelCreation, checkAndAdaptMomArms, sampleInputFile, useASTool, useDirectKinematics4TibRotEstimationAsFallback, useStatic4FrontAlignmentAsFallback, tibTorsionAdaptionMethod, InputData, pelvisWidthGenericModel, scalePelvisManually, varNameKneeAngle_c3d)


% This file scales the *.osim model using the API and opensim from the
% bin folder.
%
% INPUT:
%   - rootWorkingDirectory: folder with c3d, trc, mot files
%   - workingDirectory: full path to the folder populating the c3d files
%   - path2GenericModels: full path to generic models in repository
%   - bodymass: bodymass of subject in kg
%   - static_trc_fileName: string, filename of static trials used for
%     scaling, e.g. 'static01.trc'
%   - side: string, specifies which model should be created and scaled
%     'left' or 'right'
%   - ...

% Written by:           Brian Horsak - brian.horsak@fhstp.ac.at
% Acknowledgements:     Many thx to Bryce Killian (KU Leuven) for his great
%                       support
%
% Last changed:         06/2025
% -------------------------------------------------------------------------


%% Gather all necessary information

% Create lab specific vars
switch Model2Use
    case 'lernergopal'
        switch labFlag

            case 'ISW'
                error('Under construction: needs to be coded yet.');

            case 'FHCWnoArms'
                markerSetPath = 'OSS_FHCWnoArms\FHCWnoarms_Cleveland_MarkerSet_LernerGopal.xml';
                path2ScaleFile = char(fullfile(path2GenericModels,'OSS_FHCWnoArms\'));
                usedModel  = 'Lernagopal_41_OUF';
                scaleTemplate = 'FHCWnoArms_Scaling_LernerGopal.xml';

            case {'OSSnoArms', 'FHSTPnoArms'}
                markerSetPath = 'OSS_FHSTPnoarms\OSSnoArms_Cleveland_MarkerSet_LernerGopal.xml';
                path2ScaleFile = char(fullfile(path2GenericModels,'OSS_FHSTPnoArms\'));
                usedModel  = 'Lernagopal_41_OUF';
                scaleTemplate = 'OSSnoArms_Scaling_LernerGopal.xml';

            case 'FF'
                markerSetPath = 'FrankFurt\FF_MarkerSet_Lernagopal.xml';
                path2ScaleFile = char(fullfile(path2GenericModels,'FrankFurt\'));
                usedModel  = 'Lernagopal_41_OUF';
                scaleTemplate = 'FF_Scaling_Lernagopal.xml';
            otherwise
                warning('Unknown labFlag: %s in prepareScaledModel. Skript paused!', labFlag);
                pause()        
        end

    case 'rajagopal'
        switch labFlag

            case {'ISW', 'FF'}
                error('Under construction: needs to be coded yet - see prepareScaledModel');

            case 'FHCWnoArms'
                markerSetPath = 'OSS_FHCWnoArms\FHCWnoArms_Cleveland_MarkerSet_Rajagopal.xml';
                path2ScaleFile = char(fullfile(path2GenericModels,'OSS_FHCWnoArms\'));
                usedModel  = 'Rajagopal2015_noArms';
                scaleTemplate = 'FHCWnoArms_Scaling_Rajagopal.xml';

            case {'OSSnoArms', 'FHSTPnoArms'}
                markerSetPath = 'OSS_FHSTPnoArms\OSSnoArms_Cleveland_MarkerSet_Rajagopal.xml';
                path2ScaleFile = char(fullfile(path2GenericModels,'OSS_FHSTPnoArms\'));
                usedModel  = 'Rajagopal2015_noArms';
                scaleTemplate = 'OSSnoArms_Scaling_Rajagopal.xml';

            case {'OSS', 'FHSTP-BIZ', 'FHSTP'}
                markerSetPath = 'OSS_FHSTP\OSS_Cleveland_MarkerSet_Rajagopal.xml';
                path2ScaleFile = char(fullfile(path2GenericModels,'OSS_FHSTP\'));
                usedModel  = 'Rajagopal2015';
                scaleTemplate = 'OSS_Scaling_Rajagopal.xml';

            otherwise
                warning('Unknown labFlag: %s in prepareScaledModel. Skript paused!', labFlag);
                pause()
        end

    case 'LaiUhlrich'
        switch labFlag

            case {'ISW', 'FHCWnoArms', 'FF'}
                error('Under construction: needs to be coded yet - see prepareScaledModel');

            case {'OSSnoArms', 'FHSTPnoArms'}
                markerSetPath = 'OSS_FHSTPnoArms\OSSnoArms_cleveland_MarkerSet_LaiUhlrich.xml';
                path2ScaleFile = char(fullfile(path2GenericModels,'OSS_FHSTPnoArms\'));
                usedModel  = 'LaiUhlrich2022noArms';
                scaleTemplate = 'OSSnoArms_Scaling_LaiUhlrich.xml';

            case {'FHSTP-pyCGM'}
                markerSetPath = 'FHSTP-pyCGM\FHSTP_ClevePyCGM_MarkerSet_LaiUhlrich.xml';
                path2ScaleFile = char(fullfile(path2GenericModels,'FHSTP-pyCGM\'));
                usedModel  = 'LaiUhlrich2022';
                scaleTemplate = 'FHSTP_Scaling_LaiUhlrich.xml';
            case {'FHSTP_pyCGM2_5'}
                markerSetPath = 'FHSTP_pyCGM2_5\FHSTP_pyCGM2_5_MarkerSet_LaiUhlrich.xml';
                path2ScaleFile = char(fullfile(path2GenericModels,'FHSTP_pyCGM2_5\'));
                usedModel  = 'LaiUhlrich2022';
                scaleTemplate = 'FHSTP_pyCGM2_5_Scaling_LaiUhlrich.xml';

            case {'FHSTP_pyCGM2_5noArms'}
                markerSetPath = 'FHSTP_pyCGM2_5_noArms\FHSTP_pyCGM2_5_noArms_MarkerSet_LaiUhlrich.xml';
                path2ScaleFile = char(fullfile(path2GenericModels,'FHSTP_pyCGM2_5_noArms\'));
                usedModel  = 'LaiUhlrich2022';
                scaleTemplate = 'FHSTP_pyCGM2_5_noArms_Scaling_LaiUhlrich.xml';
            
            case {'UMC_HBMnoArms'}
                markerSetPath = 'UMC_HBMnoArms\UMCnoArms_HBM_MarkerSet_LaiUhlrich.xml';
                path2ScaleFile = char(fullfile(path2GenericModels,'UMC_HBMnoArms\'));
                usedModel  = 'LaiUhlrich2022noArms';
                scaleTemplate = 'UMCnoArms_Scaling_LaiUhlrich.xml';

            otherwise
                warning('Unknown labFlag: %s in prepareScaledModel. Skript paused!', labFlag);
                pause()
        end

    case 'RajagopalLaiUhlrich2023'
        switch labFlag

            case {'OSS', 'OSS-pyCGM'}
                markerSetPath = 'OSS_FHSTP\OSS_pyCGM_Cleveland_MarkerSet_RajaLaiUhlrich_2023.xml';
                path2ScaleFile = char(fullfile(path2GenericModels,'OSS_FHSTP\'));
                usedModel  = 'RajagopalLaiUhlrich2023';
                scaleTemplate = 'OSS_pyCGM_Scaling_RajaLaiUhlrich_2023.xml';
            otherwise
                warning('Unknown labFlag: %s in prepareScaledModel. Skript paused!', labFlag);
                pause()

        end
end

% Check if vars exist. If not raise error.
variables = {'markerSetPath', 'path2ScaleFile', 'usedModel', 'scaleTemplate'}; % List of variable names

for i = 1:length(variables)
    if ~exist(variables{i}, 'var')
        error('The combination of the selected model and markerset seems not to be implemented yet! See prepareScaledModel function.');
    end
end

% Define file paths
path.genModels = char(fullfile(path2GenericModels));
path.workingDirectory = char(workingDirectory);
path.scaleFile = char(path2ScaleFile);
path.static = strcat(rootWorkingDirectory, static_trc_fileName);
path.markerSet = strcat(path.genModels, markerSetPath);
path.geometry = strcat(workingDirectory, 'Geometry\');
path.opensim = path2opensim;
trialInfo.BM = bodymass;

% Get start and stop time of static file
trc = read_trcFile(char(path.static));
startTime = trc.Data(2,2);
stopTime = trc.Data(15,2);  % take only the first 15 frames to speed up the total process.


%% Some houesekeeping variables

% Check if model already exists <<<< under contruction >>>
% Change to working directory
cd(workingDirectory);


%% Prepare scaling in OpenSim API

% Copy model to working directory
path.genModel = strcat(path.genModels, usedModel,'.osim');
path.genModel4Scaling = fullfile(path.workingDirectory,strcat(usedModel,'_locked4Scaling.osim'));
copyfile(path.genModel, path.genModel4Scaling);

%% Change generic model in working directory and lock subtalar, MTP for scaling.
if lockSubtalar4Scaling

    % Load model
    modelFile = fullfile(path.genModel4Scaling);

    % Adapt model if selected, e.g. lock MTP,
    lockUnlockJoint(modelFile, [], 'subtalar_r', 'lock', 0);
    lockUnlockJoint(modelFile, [], 'subtalar_l', 'lock', 0);
end

%% Check if we want to scale the pelvis "manually" - then we need to use the
% _PelvisManual" version of the scaleTemplate file.

% Get Pelvis Size from first trial
fn = fieldnames(InputData);
hipdWidth = InputData.(fn{1}).HipWidth;

if scalePelvisManually && ~isnan(hipdWidth)
    scaleTemplate = [scaleTemplate(1:end-4), '_PelvisManualScaling.xml'];
end

%% Copy scale setting file to working directory
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

% Now proceed with TorisonTool
if (torsiontool.tibTorsionAdaption || torsiontool.neckShaftAdaption || torsiontool.femurAntetorsionAdaption) && TorsionOk && strcmp(tibTorsionAdaptionMethod, 'fromExtDataFile')
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
    [path.genModel4Scaling, path.markerSet4Scaling, torsionTool_out] = TorsionToolAllModels(torsiontool, persInfo, path, path.genModel4Scaling, rootWorkingDirectory, workingDirectory, 'bothSides');

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
    persInfo4TTfromStaticOnly.TTR_degree = round(getTTangleFromDirKinemStatic(staticC3d, InputData, 'r', varNameKneeAngle_c3d));
    persInfo4TTfromStaticOnly.TTL_degree = round(getTTangleFromDirKinemStatic(staticC3d, InputData, 'l', varNameKneeAngle_c3d));

    torsiontool4TTfromStaticOnly = torsiontool;
    torsiontool4TTfromStaticOnly.femurAntetorsionAdaption = false; % just to make sure the values are not rotated again in case they were.
    torsiontool4TTfromStaticOnly.neckShaftAdaption = false; % just to make sure the values are not rotated again in case they were.

    % Start TorsionTool
    disp('>>>>> TorsionTool started ...');
    [path.genModel4Scaling, path.markerSet4Scaling, torsionTool_out] = TorsionToolAllModels(torsiontool4TTfromStaticOnly, persInfo4TTfromStaticOnly, path, path.genModel4Scaling, rootWorkingDirectory, workingDirectory, 'bothSides');

else
    % Run standard tool - User decided to not use the TorsionTool for any adjustments OR dataFile was not available.
    % The following lines of code only specify NaNs for the model adjustment info since we always have to initialize the variables.

    % Set standard paths
    path.markerSet4Scaling = path.markerSet;

    % Store adaption settings.
    torsionTool_out.tibTorsionAdaption = mat2str(torsiontool.tibTorsionAdaption);
    torsionTool_out.femurAntetorsionAdaption = mat2str(torsiontool.femurAntetorsionAdaption);
    torsionTool_out.neckShaftAdaption = mat2str(torsiontool.neckShaftAdaption);

    % Initialize output values to standard values when they are not used/changed.
    torsionTool_out.AVR = NaN;
    torsionTool_out.AVL = NaN;
    torsionTool_out.NSAR = NaN;
    torsionTool_out.NSAL = NaN;
    torsionTool_out.TTR = NaN;
    torsionTool_out.TTL = NaN;

    % In case we intended to use the Torsiontool tell user that we skipped it because the data file containing the personalization info was missing or wrong.
    if (torsiontool.tibTorsionAdaption || torsiontool.neckShaftAdaption || torsiontool.femurAntetorsionAdaption) && ~TorsionOk
        warning('Model personalization file in WD for torsion tool was either not found or data Examination date and MRI-CT date were too far apart! TorsionTool skipped.');
    end
end

% In case user decided to change the TT using the external dataFile BUT either the file was not available
% OR the value in the file was NaN this will be the fallback solution.
if useDirectKinematics4TibRotEstimationAsFallback && ~strcmp(tibTorsionAdaptionMethod, 'fromStatic')
    if torsiontool.tibTorsionAdaption && ~TorsionOk || torsiontool.tibTorsionAdaption && isnan(persInfo.TTR_degree) && isnan(persInfo.TTL_degree) % note that here the fallback only applies when both TTL and TTR are NaN. In case only one is NaN it won`t work.

        % Specify the TT value using the data from the static trial and the markers specified in <start.m>.
        acq = btkReadAcquisition(staticC3d);
        btkCloseAcquisition(acq);

        % Initialize new personalization infos.
        persInfo4TTfromStaticOnly = persInfo;

        % Set new personalization infos.
        persInfo4TTfromStaticOnly.TTR_degree = round(getTTangleFromDirKinemStatic(staticC3d, InputData, 'r', varNameKneeAngle_c3d));
        persInfo4TTfromStaticOnly.TTL_degree = round(getTTangleFromDirKinemStatic(staticC3d, InputData, 'l', varNameKneeAngle_c3d));

        torsiontool4TTfromStaticOnly = torsiontool;
        torsiontool4TTfromStaticOnly.femurAntetorsionAdaption = false; % just to make sure the values are not rotated again in case they were.
        torsiontool4TTfromStaticOnly.neckShaftAdaption = false; % just to make sure the values are not rotated again in case they were.

        % Start TorsionTool
        warning('>>>>> TorsionTool (fallback-solution) started ONLY for TibialTorsion using the torsion information derived from the static trial ...');
        [path.genModel4Scaling, path.markerSet4Scaling, torsionTool_out] = TorsionToolAllModels(torsiontool4TTfromStaticOnly, persInfo4TTfromStaticOnly, path, path.genModel4Scaling, rootWorkingDirectory, workingDirectory, 'bothSides');
    end
end


%% Adapt frontal tibio-femoral angles in models before scaling (if tf_angle is ~= 0)
% Right and Left separately and after each other.

[path.genModel4Scaling, tf_angle_right, tf_angle_fromSource_r] = adjustFrontAlignmentModel(path.genModel4Scaling, tf_angle_r, tf_angle_fromSource, 'right', staticC3d, BodyHeight, bodymass, persInfo, useStatic4FrontAlignmentAsFallback, Model2Use, rootWorkingDirectory, varNameKneeAngle_c3d.R, varNameKneeAngle_c3d.posFront);
[path.genModel4Scaling, tf_angle_left, tf_angle_fromSource_l] = adjustFrontAlignmentModel(path.genModel4Scaling, tf_angle_l, tf_angle_fromSource, 'left', staticC3d, BodyHeight, bodymass, persInfo, useStatic4FrontAlignmentAsFallback, Model2Use, rootWorkingDirectory, varNameKneeAngle_c3d.L, varNameKneeAngle_c3d.posFront);

%% Collect the median frontal knee value from the static and the tib torsion only for documentation.
% These values are used for eg the valgus/varus estimation and the tib.
% torsion estimation. And this only works reliabliy for the "Cleveland
% markerset".

try
    acq = btkReadAcquisition(staticC3d);
    angles = btkGetAngles(acq);
    markers = btkGetMarkers(acq);
    btkCloseAcquisition(acq);

    % Initialize struct to hold data.
    persInfoFromMarkers = struct();

    % Right side.
    LT = mean(markers.(tib_torsion_Markers_Right{1}));
    MT = mean(markers.(tib_torsion_Markers_Right{2}));
    MMAL = mean(markers.(tib_torsion_Markers_Right{4}));
    LMAL = mean(markers.(tib_torsion_Markers_Right{3}));
    TOE = mean(markers.(tib_torsion_Markers_Right{5}));
    tibTorsFromMarker_Right = estimateTibiaTorsion(LT, MT, MMAL, LMAL, TOE);

    % Left side.
    LT = mean(markers.(tib_torsion_Markers_Left{1}));
    MT = mean(markers.(tib_torsion_Markers_Left{2}));
    MMAL = mean(markers.(tib_torsion_Markers_Left{4}));
    LMAL = mean(markers.(tib_torsion_Markers_Left{3}));
    TOE = mean(markers.(tib_torsion_Markers_Left{5}));
    tibTorsFromMarker_Left = estimateTibiaTorsion(LT, MT, MMAL, LMAL, TOE);

    persInfoFromMarkers.kneeFrontFromDirectKinematics_Right = median(angles.RKneeAngles(:,2));
    persInfoFromMarkers.kneeFrontFromDirectKinematics_Left = median(angles.LKneeAngles(:,2));
    persInfoFromMarkers.tibTorsFromDirectKinematics_Right = median(angles.RKneeAngles(:,3));
    persInfoFromMarkers.tibTorsFromDirectKinematics_Left = median(angles.LKneeAngles(:,3));
    persInfoFromMarkers.tibTorsFromMarkers_Right = tibTorsFromMarker_Right;
    persInfoFromMarkers.tibTorsFromMarkers_Left = tibTorsFromMarker_Left;

catch
    persInfoFromMarkers = struct();
    persInfoFromMarkers.kneeFrontFromDirectKinematics_Right = nan;
    persInfoFromMarkers.kneeFrontFromDirectKinematics_Left = nan;
    persInfoFromMarkers.tibTorsFromDirectKinematics_Right = nan;
    persInfoFromMarkers.tibTorsFromDirectKinematics_Left = nan;
    persInfoFromMarkers.tibTorsFromMarkers_Right = nan;
    persInfoFromMarkers.tibTorsFromMarkers_Left = nan;
end

%% Now scale the models using the standard or the AST Scale Tool.
% Load the API
import org.opensim.modeling.*

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
        path2BaseModel = path.genModel4Scaling;
        path2trc = path.static;
        path2SetUpFile = xml_file;
        workingDir4AST = fullfile(path.scaling, 'ASTool');

        % Attach markerset to model in case it is not attached.
        modelTmp = Model(path.genModel4Scaling);
        if modelTmp.getMarkerSet().getSize() == 0

            markerSet = MarkerSet(path.markerSet4Scaling);
            % Add each marker from the marker set to the model
            for i = 0 : markerSet.getSize()-1
                marker = markerSet.get(i);
                modelTmp.addMarker(marker);
            end
            state = modelTmp.initSystem();
            modelTmp.print(path.genModel4Scaling);
        end

        % Get total body mass from generic model.
        modelTmp = Model(path.genModel4Scaling);
        state = modelTmp.initSystem();
        TotalBodyMassGenModel = modelTmp.getTotalMass(state);

        % Set model geometry search path.
        ModelVisualizer.addDirToGeometrySearchPaths(path.geometry);
        state = modelTmp.initSystem();
        modelTmp.print(path.genModel4Scaling);

        % Input data for model and subject mass and height for initial scaling.
        modelData.SubjectHeight = BodyHeight/10;                        % Height of generic model (cm). Note the conversion from mm to cm!
        modelData.SubjectWeight = trialInfo.BM;                         % Weight of subject (Kg)
        modelData.GenericModelHeight = bodyheightGenericModel/10;       % Height of generic model (cm). Note the conversion from mm to cm!
        modelData.GenericModelWeight = TotalBodyMassGenModel;           % Total Body Mass generic model.

        % Set last AST inputs.
        trcScale = 1; % default = 1 for autoSIM workfow. For trc files in mm 1000 for trc files in m 1.
        setPose = 1;  % 1 = recommended by AST.

        % Now call the AST tool.
        ASTmodel = ASTool(path2BaseModel, path2trc, path2SetUpFile, workingDir4AST, modelData, setPose, '', trcScale);

        % Now copy the model out of the AST folder back to Working Directory.
        [~,name,~] = fileparts(path.genModel4Scaling); % Make scaled model name
        path2scaledModel = strcat(workingDirectory,name(1:end-15),'-ASTscaled.osim');
        copyfile(ASTmodel, path2scaledModel);

    case false
        %% Change xml ScaleSettings file
        xml_file = strcat(path.scaling, scaleTemplate);
        changeXML(xml_file,'mass',char(num2str(trialInfo.BM)),1);
        changeXML(xml_file,'model_file',path.genModel4Scaling,1); % use the locked model!
        changeXML(xml_file,'marker_set_file', path.markerSet,1); %marker set
        changeXML(xml_file,'marker_file',path.static,2); % 2 -> change twice, also for second node in marker placer
        changeXML(xml_file,'time_range',num2str([startTime stopTime]),2); % 2 -> change twice, also for second node in marker placer

        % Create model name
        path2scaledModel = erase(strcat(path.genModel4Scaling(1:end-5),'-scaled.osim'), '_locked4Scaling');

        changeXML(xml_file,'output_model_file',' ' ,1); % keep empty because otherwise I need to unlock the joints as well!
        changeXML(xml_file,'output_model_file',path2scaledModel,2,2); % change second node only
        scaleFactorFile = char(strcat(path.workingDirectory,'Scaling\',usedModel,'-ScaleFactors.xml'));
        changeXML(xml_file,'output_scale_file',scaleFactorFile,1);
        changeXML(xml_file,'output_motion_file',char(strcat(path.workingDirectory,'Scaling\',usedModel,'-Static.mot')),1);

        %% Run OpenSim Scaling in Matlab Window (this ensures that matlab will proceed only when scaling is finished)

        [~,out] = system(char(strcat(path.opensim ,'opensim-cmd',{' '}, 'run-tool',{' '}, xml_file)),'-echo');

        % Write Scaling log to text file
        txt = strcat(path.scaling,'ScalingLog.txt');
        fid = fopen(txt,'wt');
        fprintf(fid, '%s\n%s\n', out);
        fclose(fid);

end

%% Undo the locking
if lockSubtalar4Scaling
    % Load model
    modelFile = fullfile(path2scaledModel);

    % Adapt model if selected, e.g. lock MTP,
    lockUnlockJoint(modelFile, [], 'subtalar_r', 'unlock', 0);
    lockUnlockJoint(modelFile, [], 'subtalar_l', 'unlock', 0);
end

%% Scale the muscle max isometric force
scaleMuscleStrength = lower(scaleMuscleStrength);
apiPath = ''; % not necessary for lerner but for Lenhart (aka comak)

switch scaleMuscleStrength
    case 'no'
        disp('>>>>> Muscle strength of model will not be adjusted!')

    case 'manually'
        disp(['>>>>> Muscle strength of model scaled by manual value of <',num2str(manualMusScaleF),'>!'])
        path2scaledModelwithStrength = strcat(path2scaledModel(1:end-5),'_MslScaled.osim');
        strengthScaler(manualMusScaleF, apiPath, path2scaledModel, path2scaledModelwithStrength);
        path2scaledModel = path2scaledModelwithStrength;

    case {'height2pow2', 'height2pow3'} % see paper “How much muscle strength is required to walk in a crouch gait?”  https://doi.org/10.1016/j.jbiomech.2012.07.028

        if strcmp(scaleMuscleStrength, 'height2pow2')
            Power = 2;
        elseif strcmp(scaleMuscleStrength, 'height2pow3')
            Power = 3;
        end

        ScaleF = (BodyHeight / bodyheightGenericModel)^Power;

        disp(['>>>>> Muscle strength of model scaled by "', scaleMuscleStrength,'" <',num2str(ScaleF),'>!']);
        path2scaledModelwithStrength = strcat(path2scaledModel(1:end-5),'_MslScaled.osim');
        strengthScaler(ScaleF, apiPath, path2scaledModel, path2scaledModelwithStrength);
        path2scaledModel = path2scaledModelwithStrength;
end

%% Clean saved models

% Change to working directory
cd(workingDirectory);

% Add prefix to model Name and save model
newModelPath = strcat(path2scaledModel(1:end-5), '_', prefix,'.osim');
copyfile(path2scaledModel,newModelPath);
path2scaledModel = newModelPath;

% Delete all unecessary models
files2delete = dir(fullfile(path.workingDirectory, '*.osim')); % find all relevant *.osim files
files2delete = {files2delete(:).name};
[~,tmpName,~] = fileparts(newModelPath); % name of the final *.osim file
idx1 = find(contains(files2delete,strcat(tmpName,'.osim')));
idx2 = find(~contains(files2delete,usedModel)); % get the name of the currently used Model and side
idx = [idx1, idx2];
files2delete(idx) = []; % remove the final *.osim file from list
delete(files2delete{:});

% Now delete all tmp models to get rid of the TorsionTool leftovers
files2delete = dir(fullfile(path.workingDirectory, 'tmpTorsionTool*.osim')); % find all relevant *.osim files
if ~isempty(files2delete)
    files2delete = {files2delete(:).name};
    delete(files2delete{:});
end

%% Check for muscle moment arm discontinuities and try to resolve.

% Only needed for one side since the contralateral side has also data.
if checkAndAdaptMomArms
    setupFile = fullfile(path.scaleFile, 'simpleIKsettings2checkMomArms.xml');

    % Try to run IK. We need IK to run the muscle moment check tool.
    [resultsAreValid, IK_results_OutputPath] = runSimpleIKTask(setupFile, path2scaledModel, sampleInputFile, fullfile(path.workingDirectory), '');

    % IF IK was successfull check for muscle moment arm discontinuities.
    if resultsAreValid
        [MomArmsResolved, path2scaledModel] = adaptWrappingObjectsToCorrectMuscleMomentArms(path2scaledModel, IK_results_OutputPath, '');
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
disp(char(strcat('>>>>> Scaling of model done for:', {' '}, [name,ext])));


%% Clear variables except output to prevet memory leak.
clearvars -except path2scaledModel torsionTool_out tf_angle_fromSource_r tf_angle_fromSource_l tf_angle_right tf_angle_left MomArmsResolved persInfoFromMarkers
end