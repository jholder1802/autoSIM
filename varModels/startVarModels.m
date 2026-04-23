clear all; close all; clc;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Starting the MODEL workflow %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This file is used to start the "various models (var)" workflow.m function.
% The code and functions included below create all necessary input variables
% to run the <Model_workflow.m> pipeline. It assumes that all relevant *.c3d files
% are stored in one single directory (workingDirectory) and creates all
% necessary *.trc and *.mot files as well as relevant input data for
% the workflow.
%
% The workflow is mainly designed for walking trials but can be extended
% easily to work for other event configurations. Note that this workflow
% needs *.enf files (Vicon nexus database specific) text files, holding
% information about force plate contact (left, right, invalid) and a Vicon
% specific *.mp file holding information such as body weight.
% See the example data folder for details.
%
% Note: Before running your data change some hardcoded settings/paths
% below (Hardcoded setting & USER Settings). An potentially your will also
% need to make path adjustments in deeper functions.
%
% Written by:           Brian Horsak - brian.horsak@fhstp.ac.at
%
% Last changed:         03/2026
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% ------------------------------------------------------------------------
% Hardcoded paths - nothing to do here ------------------------------------
% -------------------------------------------------------------------------

% Clean Matlab Path (optional)
restoredefaultpath

% Get path where start file is located on disc and set that as the repoPath
% Note that the start file needs to to located in its original location,
% within the repo top lvl folder.
tmpPath = mfilename('fullpath');
[repoPath, ~, ~] = fileparts(tmpPath);
repoPath = strcat(repoPath,'\');

% Paths to this repository (setup files and opensim executable)
% Make sure that all paths have a '\' at the end!
path2bin = fullfile(repoPath, 'NaN');
path2opensim = fullfile(repoPath, '\opensim\');
path2setupFiles = fullfile(repoPath, '\setupFiles\');

% Add all repo subfolders (including the btk tool) to the Matlab path
addpath(genpath(fullfile(repoPath)));

% Also add common Files
addpath(genpath(fullfile(strcat(repoPath,'\..\_commonFiles'))));

% Save repo path for later.
repoPaths.repo = repoPath;
repoPaths.commonFiles = fullfile(strcat(repoPath,'\..\_commonFiles'));

% ------------ START SUPER LOOP -------------------------------------------
% Your database folder to analyze:
rootDirs = {'E:\LocDat\GitHub\autoSIM\_commonFiles\dataExamples\OSS\'};

% OR in case you have several databases:
% rootDirs = {'E:\OSS1\', ...
% 'E:\OSS2\', ...
% 'E:\OSS3\', ...
% 'E:\OSS4\', ...
% 'E:\OSS5\', ...
% 'E:\OSS6\', ...
% 'E:\OSS7\'};


for j = 1 : length(rootDirs)
    %% ========================================================================
    % User Settings - make your choices =======================================
    % =========================================================================

    % Which model do you want to use?
    Model2Use = 'lernergopal'; % 'lernergopal', 'rajagopal', 'LaiUhlrich', 'RajagopalLaiUhlrich2023' ....

    %% ===== Before you start the first time ==================================

	% Set the current root directory
    rootDirectory = rootDirs{j}; % The root folder populating all of your working directories
	
    % Consider to run this function once on your rootDirectory to eliminate any
    % special characters in your database paths that might raise errors during
    % processing! NOTE: this only has to be done once, you then should
    % use the updated pathnames for your workingDirectories in the next
    % section!
    renameFolders(rootDirectory, {',', ' ','(',')'}); % <--- uncomment if needed!

    %% ===== Set the data to process ==========================================

    % Select Option 1 out of 3:
    Option = 1;

    switch Option
        case 1
            %----- Option #1 ----------------------------------------------------------
            % Manual list of working directories to process. You can only specify one single folder. These folders contain all *.c3d files to analyze for a single subject
            % OpenSim automatically looks for that folder here. If not found in workingDirectory\Geometry, it will look at the standard OpenSim Paths.
            % Make sure that all paths have a '\' at the end!
            %---
            workingDirectories = {'E:\LocDat\GitHub\autoSIM\_commonFiles\dataExamples\OSS\'}; % {'D:\...\', 'C:\...\', ...} or {'D:\....\'}
            staticC3dFiles = {'Static.c3d'}; % {'Static01.c3d', 'Static.c3d', ...} or {'Static01.c3d'}            

        case 2
            %----- Option #2 ----------------------------------------------------------
            % Create workingDirectories and staticC3dFiles automatically and store a local file in the rootDirectory for later usage.
            % If the following line is uncommented it will create the lists of <workingDirectories> and <staticC3dFiles>
            % automatically based on the specified string pattern, e.g., 'Static' or 'Stand', etc. Note, this will overwrite the above two variables.
            % You can choose between two methods: 'byC3dFilePatternName' == looking for the appropriate file by the c3d file name pattern provided by the last
            % inputvar (e.g., 'static') OR by 'byEnfDescription' which wil look for the file based on the description in the *.enf file. The latter is the standard for the OSS.
            % Note that the function will look for all Stand* trials also Stand01, etc. ... based on the OSS specific *.enf description, however, the function should only come up with one solution
            % Note that the third input is a string pattern for which the script would look at the end of potential static trials, i.e. "A" for "StandA" trials.
            %---
            [workingDirectories, staticC3dFiles] = getTopLvlFoldersStatics(rootDirectory, 'byEnfDescription', 'Stand', ''); % default (OSS only!) = 'byEnfDescription', 'Stand', '';  default (general) = 'byC3dFilePatternName', 'Static', '';


        case 3
            %----- Option #3 ----------------------------------------------------------
            % Read [workingDirectories, staticC3dFiles] from local file which was
            % created either manually or by Option #2 in an earlier stage. You can
            % specify here from which index it should start. This is the best option for large-scale simulation tasks.
            %---
            startIdx = 1;  % default = 1
            stopIdx = NaN; % default = NaN (== to last wd); you can also specify a stop index here.
            [workingDirectories, staticC3dFiles] = readWDsFromFile(rootDirectory, startIdx, stopIdx);
    end

    % Rename all c3d files based on their descriptions in the *.enf files?
    % If there is no Description, files will be changed to NoEnfDescriptionFound_X.Trial.enf
    renameC3DFiles2enfDescription = true; % default (OSS only!) = true; otherwise false

    % Define type of files; For mSEBT directions: AT - PM - PL (these need to be the definitions from the *.enf files!)
    % This string is used to filter all potential found *.c3d files in a
    % directory and is based on the actual file name of each *.c3d.
    conditions =  {'WalkA'}; % {'WalkA'} or {'Dynamic'} OR {'mSEBT_AT','mSEBT_PM','mSEBT_PL'}

    %% ===== Simulation Settings ==============================================

    %%----- Set time frames to process ----------------------------------------
    % Use events from the c3d files to crop trials to sequences? This works for
    % "walking" and the "mSEBT" condition. If false, the full trial from the
    % first to the last frame will be processed. Note that the reporting migth
    % not work if set to false, since the reporting code is geared to "walking".
    useC3Devents = true; % default = true; true or false.

    %%----- Scale Muscles -----------------------------------------------------
    % Scale <max. isometric muscle force> manually by using a self-specified scalefactor for all muscles,
    % scale the model based on "Body Height Squared Method", or don't scale muscle
    % force. The "Body Height Squared Method" is based on the paper of van der Krogt
    % (https://doi.org/10.1016/j.gaitpost.2012.01.017) and uses the (ratio of the
    % body heights)^2 as the scale factor.

    switch Model2Use
        case 'lernergopal'
            bodyheightGenericModel = 1657;           % in mm; for the LernerGopal Model this is  1657 mm
            pelvisWidthGenericModel = 243;           % ASIS-ASIS in mm

        case 'rajagopal'
            bodyheightGenericModel = 1680;           % in mm; for the Rajagopal Model this is  1680mm
            pelvisWidthGenericModel = NaN;           % ASIS-ASIS in mm

        case 'LaiUhlrich'
            bodyheightGenericModel = 1662;           % in mm; for the Rajagopal Model this is  1662mm
            pelvisWidthGenericModel = NaN;           % ASIS-ASIS in mm

        case 'RajagopalLaiUhlrich2023'
            bodyheightGenericModel = 1664;           % in mm; for the Rajagopal-Lai_Uhlrich Model this is  1664mm
            pelvisWidthGenericModel = 254;           % ASIS-ASIS in mm
    end

    scaleMuscleStrength = 'height2pow2'; % default = 'height2pow2', height2pow3, 'No', 'manually', 'HeightSquared'
    manualMusScaleF = 0;

    %%----- Use Automatic Scaling Tool AST? -----------------------------------
    %Do you want to use the The Automated Scaling Tool (AST) to automate the
    % OpenSim Scaling process. It achieves this by iteratively adjusting
    % virtual markers to evaluate the root mean square error (RMSE) and maximum
    % marker error, taking corrective actions until the desired accuracy
    % is reached. See: https://doi.org/10.1016/j.compbiomed.2024.108524

    % NOTE: not yet recommended, results are still questionable.
    useASTool = false; % default = false; true or false;

    %%----- Scale Pelvis Manually ---------------------------------------------
    % If yes, the pelvis width will be fetched from the *.mp file and the
    % variable "InterAsisDistance" and used to scale the pelivs manually.
	% While you have this option, our results showed using the standard scaling 
	% based on the HJC seems to be the more accurate approach. 
    scalePelvisManually = false; % default = false; or false.

    %%----- Lock Suptalar Joint -----------------------------------------------
    % Lock Subtalar for scaling? This might be usefull if you only have one
    % marker on the forefoot to force a footflat position before markers are
    % replaced during scaling.
    lockSubtalar4Scaling = true; % default = true; true or false

    %%----- Adjust Tibiofemoral Angle -----------------------------------------
    % Define if the model's frontal tibio-femoral angle should be adjusted, in degrees, Varus(+) / Valgus(-)
    % You can set manual adjustments with tf_angle_r/l. If tf_angle_fromSource is set to 'fromStatic' the tf angle from the static trial will be used based on the
    % data of the direct kinematic model outputs in the c3d file. If set to 'fromExtDataFile' the skript will try to fetch the data from an external
    % source file (data.xml). If this file is empty (and you set 'useStatic4FrontAlignmentAsFallback' to true) it will fall back to 'fromStatic'.
    % Note that this will overwrite values set in tf_angle_r/l! If you want to evaluate different varus/valgus model configurations of the same individual, indicate them in the prefix, e.g. var2, var4, ...
    
    % NOTE: in some cases we will use the knee angles from the static trial to estimate the TF angle. For this purpose we need to read the Left/Right Knee anlges fromt the static *.c3d file. The variable name needs to be specified here. 
    varNameKneeAngle_c3d.R = 'RKneeAngles';             % default = 'RKneeAngles'; this depends on how the variable is defined in your *.c3d files.
    varNameKneeAngle_c3d.L = 'LKneeAngles';             % default = 'LKneeAngles'; this depends on how the variable is defined in your *.c3d files.
    varNameKneeAngle_c3d.posFront = 2;                  % default = 2; You can specify the position (column) of the frontal plane data in your *.c3d files.
    varNameKneeAngle_c3d.posTrans = 3;                  % default = 3; You can specify the position (column) of the transverse plane data in your *.c3d files (later needed for TT).
    useStatic4FrontAlignmentAsFallback = false;          % default = false; true or false
    tf_angle_fromSource = 'false';                      % default = 'false'; 'false', 'fromStatic', 'fromExtDataFile', 'manual'
    tf_angle_r = 0;                                     % default = 0
    tf_angle_l = 0;                                     % default = 0

    %%----- Torsion Tool ------------------------------------------------------
    % Define if you want to use the TorsionTool by Veerkamp et al. (2021) to personalize the tibial torsion, femur anteversion, and neckshaft angle.
    % These valus are derived from a "data.xml" (see example data) located next to your *.c3d files or you can use the "useDirectKinematics4TibRotEstimationAsFallback"
    % to use the angle based on the direct kinematics data from the dynamic c3d files (median knee rot. during stance for all gait cycles of all trials) in case the TT information is not available from the external file.
    % You can also directly specifiy to use the direct kinematics data from the dynamic c3d files as TT value for the TorsionTool.
    % NOTE: before using the TorsionTool check the hardcoded default values in the main torsion script, since based on these the torsion will be adjusted accordingly!
    % NOTE to 'fromStatic' - we currently use the CleveLand Model (from OSS - Speising). Here external TT is NEGATIVE. Currently this values is multiplied by -1 to have the correct sign for the TorsionTool (where ext. TT is POSITIVE).
    useDirectKinematics4TibRotEstimationAsFallback = false;   % default = false; true or false;
    tibTorsionAdaptionMethod = 'fromStatic';        % default = 'fromStatic'; 'fromExtDataFile' or 'fromStatic'
    tibTorsionAdaption = false;                     % default = false; true or false
    neckShaftAdaption = false;                      % default = false; true or false
    femurAntetorsionAdaption = false;               % default = false; true or false

    %%----- Check & Adapt Wrapping Objects ------------------------------------
    % Decide whether you want to automatically check and adapt discontinuities in
    % the moment arms. If true the scaled model will be checked for
    % discontinuities in moment arms at the hip and knee and wrapping objects will be iteratively
    % reduced until discontinuities are resolved. This script is based on Willi
    % Kollers (unpublished) work.
    checkAndAdaptMomArms = true; % default = true; true or false

    %%----- Contact Geometry --------------------------------------------------
    % Define which bodypart has first contact to ground (e.g. for generating the external loads file)
    firstContact_L = 'calcn_l'; % default = 'calcn_l'
    firstContact_R = 'calcn_r'; % default = 'calcn_r'

    %%----- Pelvis Helper Marker ----------------------------------------------
    % Do you want to add pelvis helper marker to, e.g., allow for non-uniform scaling
    % of the pelvis? If yes, toggle to true. Note: you will manually need to
    % set the scaling to non-uniform in the scale setup file! Settings this to
    % true only adds the markers to the static *.trc file.
    addPelvisHelperMarker = true; % default = true; true or false

    %%----- Compute joint centers for static *.trc file? ----------------------
    % If the original *.c3d file does not contain any joint centers these
    % can be computed here. This is also helpfull in case one needs to
    % standardize the joint centers across large datasets. 
    compute_joint_centers_for_static_trc = false;    % default = false, true or false
    hjc_method = "Hara";                             % Options: "Hara", "Harrington_single"
    
    % NOTE: joint centers are only appended to the trc file - in case the c3d
    % files have already joint centers, this might lead to an error.
    % Replacing existing joint centers is not implemented yet. 

    %%----- Create MOT- and TRC-Files -----------------------------------------
    % Do you want to create *.trc and *.mot files automatically using the built-in code? If so, set to true. Note that
    % this will always overwrite any existing *.trc and *.mot files! If set to
    % false and no files are available an error will be raised.
    forceTrcMotCreation = true; % default = true; true or false

    %%----- Prefix ------------------------------------------------------------
    % Add file-prefix to distinguish different setups, for example to indicate a specfic trial 'variation', e.g. 'with_muscle_optimization'
    % Note: for convenience during group analysis it is recommended to always use a prefix!
    % Note always separate prefix conditions with '-' (standard-CE150). Do not use an '_'! Otherwise it will not work.
    prefix = 'standard'; % default = 'standard', or e.g. 'noTimeNorm', 'VarAligned2deg'

    %%----- Data Augmentation -------------------------------------------------
    % Data Augmentation-Mode. If you set this to true, each trial will be run
    % on a set of models adapted on predefined varus-valgus-tib-rotation sets. Note that the
    % prefix will be auto-generated based on the augmentation settings
    dataAugmentation = false; % default = false; true or false

    %%----- Generate new models -----------------------------------------------
    % Force Model Creation? If set to true, the workflow will always scale and
    % generate a new model. Otherwise, a model will be only created if not appropriate models are found.
    ForceModelCreation = true; % default = true; true or false

    %%----- Define witch task(s) to run ---------------------------------------
    % Depending on what is already implemented here you can decide which tasks
    % to run.

    tasks.IK = true;     % Inverse Kinematics
    tasks.ID = true;     % Inverse Dynamics
    tasks.RR = false;    % Residual Reduction - NOTE: not recommended, this does not work yet.
    tasks.SO = true;     % Static Optimization
    tasks.A =  true;     % Analyze

    %% ===== PostProcessing Settings ==========================================

    %%----- Time Normalize Results? -------------------------------------------
    % Force to time normalize all data to 100% activity.
    timeNormFlag = true; % default = true; true or false;

    %%----- Specify Type of Trials --------------------------------------------
    % Set trial type for plotting: walking or not "something else" (=notWalking)
    % This is only necessray to have the plots nicely formatted.
    trialType = 'walking'; % default = 'walking'; 'walking' or 'notWalking';

    %% =====  Processing Settings =============================================

    %%----- Set Lab  ----------------------------------------------------------
    % Define from which lab the data come from
    labFlag = 'OSSnoArms'; % 'OSS', 'OSSnoArms', 'FHSTP-BIZ', 'FHSTP', FHSTPnoArms, 'ISW', 'LKHG_Cleve', 'FF', 'FHSTP-pyCGM', 'FHCWnoArms', 'OSS-pyCGM', 'FHSTP_pyCGM2_5', FHSTP_pyCGM2_5noArms, UMC_HBMnoArms

    %%----- Set max. N of cmd windows -----------------------------------------
    % Define number of allowed simultaneously running cmd windows.
    maxCmd = 70; % default = 8 (for a Surface Book2 @i7-8650U @ 1.90Ghz) OR ~60 for 64-core server for standard simulation tasks (e.g., without AST, but with momArmCheck and TF adaption) during parallel computing

    %%----- CPU Load Threshold ------------------------------------------------
    % Define a threshold the CPU-load has to fall below (median over 1 minutes), before the next batch of files are forwarded to the cmd window.
    % In case this is set to False the workflow will use the amount of open cmd windows to control CPU load (=default).
    thresholdCpuLoad = 70;      % default ~ 40% for Laptop, ~70% for 64-core Server
    useCPUThreshold = false;    % default = false; true or false

    % NOTE: it seems that the function does not work properly for WIN11 and
    % newer Intelchips (intel core Ultra 7). It worked on WIN11 and older chipsets.

    %%----- Catch errors Y/N? -------------------------------------------------
    % Disable this for debugging when developing the code. Enable for running
    % big file batches so that errors are caught and Matlab won`t stop on an
    % error.
    catchErrors = false; % default = true

    %%----- Settings for use of Parrallell Computing --------------------------
    maxNumWorkers = 7; % this depends on your machine and task ... 7 seemed fine for my 64-core sever (for a standard scale + TF only and with momentarm checks).

    % ... but its is recommend to keep this low. For a 64-core server with 64GB,
    % RAM more than 5 workers were too much for the standard scaling. However,
    % if you have a slow scaling task, such as using AST,
    % more workers might be helpful to speed up processing.

    %% ========================================================================
    % HARDCODED Settings ======================================================
    % =========================================================================

    % Implemented marker sets and some settings based on the markersets
    switch labFlag
        case 'UMC_HBMnoArms'
            % HBM marker set full body
            markerSet = {'JN', 'XIPH', 'C7', 'T10', ...
                'RASIS','LASIS','LPSIS', 'RPSIS', ...
                'RGTRO','RLTHI','RATHI','LGTRO','LLTHI','LATHI', ...
                'RLEK','RMEK','LLEK','LMEK', ...
                'RTT', 'RFH', 'RLSHA', 'LTT', 'LFH', 'LLSHA', ...
                'RLM', 'RMM', 'LLM', 'LMM', ...
                'RHEE', 'RMT1', 'RMT2', 'RMT5', ...
                'LHEE', 'LMT1', 'LMT2', 'LMT5'
                };

            % The markers used for the appendHelperMarkers function for the nonuniform pelvis scaling.
            % Note: they always have to have the following order: {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'} or {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSI', 'RPSI'}!
            pelvisMarker4nonUniformScaling = {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSIS', 'RPSIS'};

            % Markers used to calculate the tibial torsion
            tib_torsion_LeftMarkers = {'LLEK', 'LMEK', 'LLM', 'LMM', 'LMT2'};
            tib_torsion_RightMarkers = {'RLEK', 'RMEK', 'RLM', 'RMM', 'RMT2'};

            % Markers to compute the joint centers. Note that order is important!
            if compute_joint_centers_for_static_trc == false
                compute_joint_centers_for_static_trc = true; % we foce the jc estimation since the markerset does not inlcude it anyway.
                warning("<compute_joint_centers_for_static_trc> was set to true since markerset does not have joint centers!")
            end
            jc_base_data = struct();
            jc_base_data.method = hjc_method;
            jc_base_data.hip   = ["RASIS", "LASIS", "RPSIS", "LPSIS"]; % order: RASI, LASI, SAC OR RASI, LASI, RPSI, LPSI <- left/rigth oder is important markernames can be adjusted.
            jc_base_data.knee  = ["LLEK", "LMEK", "RLEK", "RMEK"]; % order: left_lat - left_med - right_lat - right_med
            jc_base_data.ankle = ["LLM", "LMM", "RLM", "RMM" ]; % order: left_lat - left_med - right_lat - right_med

        case {'OSSnoArms', 'FHSTPnoArms', 'FHCWnoArms'}
            % Cleve marker set withou arms
            markerSet = {   'RFHD','LFHD','LBHD','RBHD',...
                'C7','T10', 'CLAV', 'STRN', 'RBAK', 'LSHO', 'RSHO', ...
                'RASI','LASI','SACR', 'RHJC', 'LHJC', ...
                'LT1','LT2','LT3','LS1','LS2','LS3', ...
                'RT1','RT2','RT3','RS1','RS2','RS3', ...
                'LKNE', 'LKJC', ...
                'RKNE', 'RKJC', ...
                'LTOE','LHEE', 'LANK', 'LAJC', ...
                'RTOE','RHEE', 'RANK', 'RAJC'};

            % The markers used for the appendHelperMarkers function for the nonuniform pelvis scaling.
            % Note: they always have to have the following order: {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'} or {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSI', 'RPSI'}!
            pelvisMarker4nonUniformScaling = {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'};

            % Markers used to calculate the tibial torsion
            tib_torsion_LeftMarkers = {'LKNE', 'LKJC', 'LANK', 'LAJC', 'LTOE'};
            tib_torsion_RightMarkers = {'RKNE', 'RKJC', 'RANK', 'RAJC', 'RTOE'};

            % Marker to compute the joint centers. Note that order is important!
            if compute_joint_centers_for_static_trc
                % Note: impossible here as long as we do not have medial knee
                % markers defined.
                compute_joint_centers_for_static_trc = false;
                warning("<compute_joint_centers_for_static_trc> was set to false since markerset does not have medial knee and ankle markers!")
            end

            jc_base_data = struct();
            jc_base_data.method = hjc_method;
            jc_base_data.hip   = ["RASI", "LASI", "SACR"]; % order: RASI, LASI, SAC OR RASI, LASI, RPSI, LPSI <- left/rigth oder is important markernames can be adjusted.
            jc_base_data.knee  = ["LKNE", "", "RKNE", ""]; % order: left_lat - left_med - right_lat - right_med
            jc_base_data.ankle = ["LANK", "", "RANK", "" ]; % order: left_lat - left_med - right_lat - right_med

        case {'OSS', 'FHSTP-BIZ', 'FHSTP'}
            % Cleve marker set full body
            markerSet = {   'RFHD','LFHD','LBHD','RBHD',...
                'C7','T10', 'CLAV', 'STRN', 'RBAK', 'LSHO', 'RSHO', ...
                'RASI','LASI','SACR', 'RHJC', 'LHJC', ...
                'LT1','LT2','LT3','LS1','LS2','LS3', ...
                'RT1','RT2','RT3','RS1','RS2','RS3', ...
                'LKNE', 'LKJC', ...
                'RKNE', 'RKJC', ...
                'LTOE','LHEE', 'LANK', 'LAJC', ...
                'RTOE','RHEE', 'RANK', 'RAJC', ...
                'RUPA', 'RELB', 'RFRA', 'RWRA', 'RWRB', 'RFIN', ...
                'LUPA', 'LELB', 'LFRA', 'LWRA', 'LWRB', 'LFIN'};

            % The markers used for the appendHelperMarkers function for the nonuniform pelvis scaling.
            % Note: they always have to have the following order: {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'} or {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSI', 'RPSI'}!
            pelvisMarker4nonUniformScaling = {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'};

            % Markers used to calculate the tibial torsion
            tib_torsion_LeftMarkers = {'LKNE', 'LKJC', 'LANK', 'LAJC', 'LTOE'};
            tib_torsion_RightMarkers = {'RKNE', 'RKJC', 'RANK', 'RAJC', 'RTOE'};

            % Marker to compute the joint centers. Note that order is important!
            if compute_joint_centers_for_static_trc
                % Note: impossible here as long as we do not have medial knee
                % markers defined.
                compute_joint_centers_for_static_trc = false;
                warning("<compute_joint_centers_for_static_trc> was set to false since markerset does not have medial knee and ankle markers!")
            end

            jc_base_data = struct();
            jc_base_data.method = hjc_method;
            jc_base_data.hip   = ["RASI", "LASI", "SACR"]; % order: RASI, LASI, SAC OR RASI, LASI, RPSI, LPSI <- left/rigth oder is important markernames can be adjusted.
            jc_base_data.knee  = ["LKNE", "", "RKNE", ""]; % order: left_lat - left_med - right_lat - right_med
            jc_base_data.ankle = ["LANK", "", "RANK", "" ]; % order: left_lat - left_med - right_lat - right_med

        case {'FHSTP-pyCGM', 'OSS-pyCGM', 'FHCW'}
            % Cleve marker set full body
            markerSet = {   'RFHD','LFHD','LBHD','RBHD',...
                'C7','T10', 'CLAV', 'STRN', 'RBAK', 'LSHO', 'RSHO', ...
                'RASI','LASI','SACR', 'RHJC', 'LHJC', ...
                'LT1','LT2','LT3','LS1','LS2','LS3', ...
                'RT1','RT2','RT3','RS1','RS2','RS3', ...
                'LKNE', 'LKNM', 'LKJC', ...
                'RKNE', 'RKNM', 'RKJC', ...
                'LTOE','LHEE', 'LANK', 'LANM', 'LAJC', ...
                'RTOE','RHEE', 'RANK', 'RANM', 'RAJC', ...
                'LD1M', 'LD5M', 'RD1M', 'RD5M', ...
                'RUPA', 'RELB', 'RFRA', 'RWRA', 'RWRB', 'RFIN', ...
                'LUPA', 'LELB', 'LFRA', 'LWRA', 'LWRB', 'LFIN'};

            % The markers used for the appendHelperMarkers function for the nonuniform pelvis scaling.
            % Note: they always have to have the following order: {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'} or {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSI', 'RPSI'}!
            pelvisMarker4nonUniformScaling = {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'};

            % Markers used to calculate the tibial torsion
            tib_torsion_LeftMarkers = {'LKNE', 'LKNM', 'LANK', 'LANM', 'LTOE'};
            tib_torsion_RightMarkers = {'RKNE', 'RKNM', 'RANK', 'RANM', 'RTOE'};

            % Marker to compute the joint centers. Note that order is important!
            jc_base_data = struct();
            jc_base_data.method = hjc_method;
            jc_base_data.hip   = ["RASI", "LASI", "SACR"]; % order: RASI, LASI, SAC OR RASI, LASI, RPSI, LPSI <- left/rigth oder is important markernames can be adjusted.
            jc_base_data.knee  = ["LKNE", "LKNM", "RKNE", "RKNM"]; % order: left_lat - left_med - right_lat - right_med
            jc_base_data.ankle = ["LANK", "LKNM", "RANK", "RKNM" ]; % order: left_lat - left_med - right_lat - right_med
        
        case {'FHSTP_pyCGM2_5'}
            % pyCGM2.5 markerset without head
            markerSet = {
                'T2','T10', 'CLAV', 'LSHO', 'RSHO', ...
                'RASI','LASI','RPSI', 'LPSI', 'RHJC', 'LHJC', ...
                'LTHAP','LTHAD','LTHI','LTIAP','LTIAD','LTIB', ...
                'RTHAP','RTHAD','RTHI','RTIAP','RTIAD','RTIB', ...
                'LKNE', 'LKNM', 'LKJC', ...
                'RKNE', 'RKNM', 'RKJC', ...
                'LTOE','LHEE', 'LANK', 'LMED', 'LAJC', ...
                'RTOE','RHEE', 'RANK', 'RMED', 'RAJC', ...
                'LVMH', 'LFMH', 'RVMH', 'RFMH', ...
                'RUPA', 'RELB', 'RWRA', 'RWRB', ...
                'LUPA', 'LELB', 'LWRA', 'LWRB'};

            % The markers used for the appendHelperMarkers function for the nonuniform pelvis scaling.
            % Note: they always have to have the following order: {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'} or {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSI', 'RPSI'}!
            pelvisMarker4nonUniformScaling = {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSI', 'RPSI'};

            % Markers used to calculate the tibial torsion
            tib_torsion_LeftMarkers = {'LKNE', 'LKNM', 'LANK', 'LMED', 'LTOE'};
            tib_torsion_RightMarkers = {'RKNE', 'RKNM', 'RANK', 'RMED', 'RTOE'};

            % Marker to compute the joint centers. Note that order is important!
            jc_base_data = struct();
            jc_base_data.method = hjc_method;
            jc_base_data.hip   = ["RASI", "LASI", "RPSI", "LPSI"]; % order: RASI, LASI, SAC OR RASI, LASI, RPSI, LPSI <- left/rigth oder is important markernames can be adjusted.
            jc_base_data.knee  = ["LKNE", "LKNM", "RKNE", "RKNM"]; % order: left_lat - left_med - right_lat - right_med
            jc_base_data.ankle = ["LANK", "LKNM", "RANK", "RKNM" ]; % order: left_lat - left_med - right_lat - right_med
        
        case {'FHSTP_pyCGM2_5noArms'}
            % pyCGM2.5 markerset without head
            markerSet = {
                'T2','T10', 'CLAV', 'LSHO', 'RSHO', ...
                'RASI','LASI','RPSI', 'LPSI', 'RHJC', 'LHJC', ...
                'LTHAP','LTHAD','LTHI','LTIAP','LTIAD','LTIB', ...
                'RTHAP','RTHAD','RTHI','RTIAP','RTIAD','RTIB', ...
                'LKNE', 'LKNM', 'LKJC', ...
                'RKNE', 'RKNM', 'RKJC', ...
                'LTOE','LHEE', 'LANK', 'LMED', 'LAJC', ...
                'RTOE','RHEE', 'RANK', 'RMED', 'RAJC', ...
                'LVMH', 'LFMH', 'RVMH', 'RFMH'};

            % The markers used for the appendHelperMarkers function for the nonuniform pelvis scaling.
            % Note: they always have to have the following order: {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'} or {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSI', 'RPSI'}!
            pelvisMarker4nonUniformScaling = {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSI', 'RPSI'};

            % Markers used to calculate the tibial torsion
            tib_torsion_LeftMarkers = {'LKNE', 'LKNM', 'LANK', 'LMED', 'LTOE'};
            tib_torsion_RightMarkers = {'RKNE', 'RKNM', 'RANK', 'RMED', 'RTOE'};
			
			% Marker to compute the joint centers. Note that order is important!
            if compute_joint_centers_for_static_trc
                % Note: impossible here as long as we do not have medial knee
                % markers defined.
                compute_joint_centers_for_static_trc = false;
                warning("<compute_joint_centers_for_static_trc> was set to false since markerset does not have medial knee and ankle markers!")
            end

            jc_base_data = struct();
            jc_base_data.method = hjc_method;
            jc_base_data.hip   = ["RASI", "LASI", "SACR"]; % order: RASI, LASI, SAC OR RASI, LASI, RPSI, LPSI <- left/rigth oder is important markernames can be adjusted.
            jc_base_data.knee  = ["LKNE", "", "RKNE", ""]; % order: left_lat - left_med - right_lat - right_med
            jc_base_data.ankle = ["LANK", "", "RANK", "" ]; % order: left_lat - left_med - right_lat - right_med
			
        case 'ISW'
            markerSet = {   'C7','T10', 'CLAV', 'STRN', 'RBAK', ...
                'RASI','LASI','RPSI', 'LPSI', ...
                'LTH1','LTH2','LTH3','LTB1','LTB2','LTB3', ...
                'RTH1','RTH2','RTH3','RTB1','RTB2','RTB3', ...
                'LTOE','LHEE', 'LDM5', ...
                'RTOE','RHEE', 'RDM5', 'RD5M', ... % there is a typo right now in the markerset 'RD5M' instead of RDM5
                'LKNE', 'LMKNE', 'RKNE', 'RMKNE', ...
                'LANK', 'LMMA', 'RANK', 'RMMA'};

            % Note we do not have HJC in the static trials so no chance for the
            % appendHelperMarkers function.

            % Markers used to calculate the tibial torsion
            tib_torsion_LeftMarkers = {'LKNE', 'LMKNE', 'LANK', 'LMMA', 'LTOE'};
            tib_torsion_RightMarkers = {'RKNE', 'RMKNE', 'RANK', 'RMMA', 'RTOE'};

            % Marker to compute the joint centers. Note that order is important!
            jc_base_data = struct();
            jc_base_data.method = hjc_method;
            jc_base_data.hip   = ["RASI", "LASI", "RPSI", "LPSI"]; % order: RASI, LASI, SAC OR RASI, LASI, RPSI, LPSI <- left/rigth oder is important markernames can be adjusted.
            jc_base_data.knee  = ["LKNE", "LMKNE", "RKNE", "RMKNE"]; % order: left_lat - left_med - right_lat - right_med
            jc_base_data.ankle = ["LANK", "LMMA", "RANK", "RMMA" ]; % order: left_lat - left_med - right_lat - right_med

        case {'LKHG_Cleve'}
            % Cleve comak marker set full body
            markerSet = {...
                'RASI','LASI','SACR', ...
                'LT1','LT2','LT3','LS1','LS2','LS3', ...
                'RT1','RT2','RT3','RS1','RS2','RS3', ...
                'LTOE','LHEE', ...
                'RTOE','RHEE', ...
                'LKNE', 'LANK', 'LKNM', 'LANM', ...
                'RKNE', 'RANK', 'RKNM', 'RANM'};

            % The markers used for the appendHelperMarkers function for the nonuniform pelvis scaling.
            % Note: they always have to have the following order: {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'} or {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSI', 'RPSI'}!
            pelvisMarker4nonUniformScaling = {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'};

            % Markers used to calculate the tibial torsion
            tib_torsion_LeftMarkers = {'LKNE', 'LMKNE', 'LANK', 'LMMA', 'LTOE'};
            tib_torsion_RightMarkers = {'RKNE', 'RMKNE', 'RANK', 'RMMA', 'RTOE'};

            % Marker to compute the joint centers. Note that order is important!
            jc_base_data = struct();
            jc_base_data.method = hjc_method;
            jc_base_data.hip   = ["RASI", "LASI", "SACR"]; % order: RASI, LASI, SAC OR RASI, LASI, RPSI, LPSI <- left/rigth oder is important markernames can be adjusted.
            jc_base_data.knee  = ["LKNE", "LKNM", "RKNE", "RKNM"]; % order: left_lat - left_med - right_lat - right_med
            jc_base_data.ankle = ["LANK", "LKNM", "RANK", "RKNM" ]; % order: left_lat - left_med - right_lat - right_med

        case 'LKHG_PiG'
            markerSet = {   'RASI','LASI','SACR', ...
                'RTHI','RTIB','RANK','RHEE','RTOE','RKNE', ...
                'LTHI','LTIB','LANK','LHEE','LTOE','LKNE'};

            % Note we do not have HJC in the static trials so no chance for the
            % appendHelperMarkers function.
            pelvisMarker4nonUniformScaling = nan;

            % Note we do not have medial knee markers which we could use for
            % the tibial torsion correction.
            tib_torsion_LeftMarkers = nan;
            tib_torsion_RightMarkers = nan;

        case 'FF'
            markerSet = {   'C7', 'T10', 'CLAV', 'STRN', 'RSHO', 'LSHO'...
                'LASI', 'RASI', 'SACR', ...
                'RFEP', 'LFEP', ...
                'RTRO', 'LTRO', 'RTHI', 'LTHI', ...
                'RKNE', 'RMCK', 'LKNE', 'LMCK', ...
                'RTIB', 'LTIB', ...
                'RANK', 'RMMA', 'RHEE', 'RTOE', 'LANK', 'LMMA', 'LHEE', 'LTOE'};

            % The markers used for the appendHelperMarkers function for the nonuniform pelvis scaling.
            % Note: they always have to have the following order: {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'} or {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSI', 'RPSI'}!
            pelvisMarker4nonUniformScaling = {'LASI', 'RASI', 'LFEP', 'RFEP', 'SACR'};

            % Note we do not have medial knee markers which we could use for
            % the tibial torsion correction.
            tib_torsion_LeftMarkers = nan;
            tib_torsion_RightMarkers = nan;

            % Marker to compute the joint centers. Note that order is important!
            if compute_joint_centers_for_static_trc
                % Note: impossible here as long as we do not have medial knee
                % markers defined.
                compute_joint_centers_for_static_trc = false;
                warning("<compute_joint_centers_for_static_trc> was set to false since markerset does not have medial knee and ankle markers!")
            end

            jc_base_data = struct();
            jc_base_data.method = hjc_method;
            jc_base_data.hip   = ["RASI", "LASI", "SACR"]; % order: RASI, LASI, SAC OR RASI, LASI, RPSI, LPSI <- left/rigth oder is important markernames can be adjusted.
            jc_base_data.knee  = ["LKNE", "", "RKNE", ""]; % order: left_lat - left_med - right_lat - right_med
            jc_base_data.ankle = ["LANK", "", "RANK", "" ]; % order: left_lat - left_med - right_lat - right_med
    end

    %% Prepare to run the workflow and postprocessing

    % Check if the prefix contains an underscore
    if contains(prefix, '_')
        disp('WARNING: Underscore detected in prefix. Stopping script. Please remove any "_" from your prefix!');
        return;
    end

    % Check if paths contain empty space - the OpenSim API does not like that.
    if contains(repoPath, ' ') || contains(rootDirectory, ' ')
        disp('WARNING: Empty spaces detected in repopath or root directory! Stopping script. AutoSIM does not support empty or special characters in paths!');
        return;
    end


    % Create Model specific path2genModels
    switch Model2Use

        case 'lernergopal'
            path2GenericModels = fullfile(repoPath, '\setupFiles\LernerGopalModels\');

        case 'rajagopal'
            path2GenericModels = fullfile(repoPath, '\setupFiles\RajagopalModels\');

        case 'LaiUhlrich'
            path2GenericModels = fullfile(repoPath, '\setupFiles\LaiUhlrichModels\');

        case 'RajagopalLaiUhlrich2023'
            path2GenericModels = fullfile(repoPath, '\setupFiles\RajagopalLaiUhlrich2023Models\');
    end

    % Make sure we use the automated prefix when using the data augmentation mode
    if dataAugmentation
        load(fullfile(path2setupFiles, 'dataAugmentationSet.mat'));
        augN = height(dataAugmentationSet); %number of augmentation cycles
        for i_dataAug = 1 : augN
            prefixCell{1,i_dataAug} = strcat('dataAug',num2str(i_dataAug));
        end
    else
        prefixCell = {prefix}; % The workflows wants the prefix as a cell array
    end

    % Create Struct variable for torsion tool
    torsiontool.tibTorsionAdaption = tibTorsionAdaption;
    torsiontool.neckShaftAdaption = neckShaftAdaption;
    torsiontool.femurAntetorsionAdaption = femurAntetorsionAdaption;

    %% Run Model processing
    disp('****************************************  preparing some things ...  *****************************************');

    % Start timer
    tStart = tic;

    % Run the workflow  in parallel tool box

    Nmax = length(workingDirectories);

    % Define the number of splits and compute batch size
    if Nmax < 30 % If Nmax is below e.g., 30 we do not need to create separated batches, since this only takes longer than using a single batch.
        split = 1; % If Nmax is below e.g., 30 we do not need to create separated batches.
        batchSize = ceil(Nmax / split);  % Use ceil to ensure no directories are missed.
    else
        batchSize = 300; % default = 300; this highly depends on your use case. E.g.: we processed 6.500 directorires, had 128GB RAM a batchsize of 300 seemed ok to prevent running out of RAM due to memory leak.
        split = ceil(Nmax/batchSize);

        %split = 10; % default = 10; this highly depends on your use case. E.g.: we processed 6.500 directorires, had 128GB RAM and needed 5 splits to prevent running out of RAM due to memory leak.
        %batchSize = ceil(Nmax / split);  % Use ceil to ensure no directories are missed.
    end

    % Loop over each batch - since there is often a memory leak, this might help
    % to prevent that Matlab runs out of RAM, since after each batch the
    % parpool gets closed and associated RAM released.
    for batchIdx = 1:split
        % Compute the start and end index for the current batch
        startIdx = (batchIdx - 1) * batchSize + 1;
        endIdx = min(batchIdx * batchSize, Nmax);  % Ensure not to exceed Nmax

        % Run the parallel loop for the current batch
        parfor_active = true;
        
        %for i_parfor = startIdx:endIdx; warning("parfor not activated!"); parfor_active = false; %#> for development only %#> for development only
        parfor (i_parfor = startIdx:endIdx, maxNumWorkers) 
            loops4Models_parfor(rootDirectory, workingDirectories, staticC3dFiles, conditions, labFlag, path2GenericModels, path2opensim, path2setupFiles, tf_angle_r, tf_angle_l, ...
                firstContact_L, firstContact_R, prefixCell, maxCmd, thresholdCpuLoad, lockSubtalar4Scaling, ...
                scaleMuscleStrength, manualMusScaleF, markerSet, bodyheightGenericModel, addPelvisHelperMarker, pelvisMarker4nonUniformScaling, tf_angle_fromSource, torsiontool, useDirectKinematics4TibRotEstimationAsFallback, ...
                tib_torsion_LeftMarkers, tib_torsion_RightMarkers, forceTrcMotCreation, ForceModelCreation, renameC3DFiles2enfDescription, ...
                Model2Use, tasks, checkAndAdaptMomArms, useASTool, i_parfor, useStatic4FrontAlignmentAsFallback, useC3Devents, useCPUThreshold, tibTorsionAdaptionMethod, pelvisWidthGenericModel, scalePelvisManually, ...
                varNameKneeAngle_c3d, compute_joint_centers_for_static_trc, jc_base_data);
        end

        % Shut down parallel pool to release allocated RAM by the parpool.
        poolobj = gcp('nocreate');
        delete(poolobj);

        % Wait for 5 minutes to see if cmd windows still get processed, otherwise force rest to close.
        %monitorCmdWindowsAndForceClose(5, 60);
    end

    if parfor_active
        % Clean up WD_parfooLoop files to single WD file.
        cleanUpParforWDFiles(fullfile(rootDirectory, strcat('_', Model2Use, '-WD-tmpLogFiles')), length(workingDirectories),  fullfile(rootDirectory, strcat('workingDirectories-', Model2Use, '_', prefix, '.xlsx')));
    end

    %% Final  message
    % End timer
    tEnd = seconds(toc(tStart));
    tEnd.Format = 'hh:mm';
    disp(''); % new line
    disp('************************************************************************************************************');
    disp(strcat('>>>>>  Total processing duration:',{' '}, string(tEnd),'(hh:mm). <<<<<'));
    disp('*******************************************  Over and out  *******************************************');
end