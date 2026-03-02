clear; close all; clc;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Starting the COMAK workflow %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This file is used to start the COMAK workflow. The code
% and functions included below create all necessary input variables to run
% the workflow. It assumes that all relevant *.c3d files
% are stored in one single directory (workingDirectory) and creates all
% necessary *.trc and *.mot files as well as relevant input data for OpenSim.
%
% The workflow accepts walking and star excursion balance test trials
% (mSEBT). Note that this workflow needs *.enf files (Vicon Nexus
% database specific) text files, holding information about force plate
% contact (left, right, invalid) and a Vicon specific *.mp file holding
% information such as body weight. See the example data folder for details.
%
% Ref. for OpenSim-JAM and COMAK: https://github.com/clnsmith/opensim-jam
%
% Written by:           Brian Horsak - brian.horsak@fhstp.ac.at
%
% Last changed:         09/2025
% Version:              See version file in autoSIM root folder.
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% For debugging only
% dbstop if error
% dbstop clear

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
path2bin = fullfile(repoPath, '\opensim-jam\bin\');
path2opensim = fullfile(repoPath, '\opensim-jam\opensim\');
path2setupFiles = fullfile(repoPath, '\setupFiles\');
path2GenericModels = fullfile(repoPath, '\setupFiles\Models\');

% Add all repo subfolders (including the btk tool) to the Matlab path
addpath(genpath(fullfile(repoPath)));

% Also add common Files
addpath(genpath(fullfile(strcat(repoPath,'\..\_commonFiles'))));

% Save repo path for later.
repoPaths.repo = repoPath;
repoPaths.commonFiles = fullfile(strcat(repoPath,'\..\_commonFiles'));

% ------------ START SUPER LOOP -------------------------------------------
% Your database folder to analyze:
if strcmp(repoPath(end),'\')
    parts = strsplit(repoPath(1:end-1), '\');
else
    parts = strsplit(repoPath, '\');
end
startpath = strjoin(parts(1:end-1), '\');

% rootDirs = {fullfile(startpath,'_data\01_2026_R2S_ACL\Absamann_SA_02\2025-02-04'),...
%             fullfile(startpath,'_data\01_2026_R2S_ACL\Buchinger_AB_09\2025-04-10')};

subjectDirs = dir(fullfile(startpath,'_data\01_2026_R2S_ACL'));
subjectDirs = subjectDirs(~contains({subjectDirs.name},'.'));

rootDirs = [];
idxDir = 0;
for n = 1:length(subjectDirs)
    sessionDir = dir(fullfile(subjectDirs(n).folder,subjectDirs(n).name));
    sessionDir = sessionDir(~contains({sessionDir.name},'.'));
    for m = 1:length(sessionDir)
        idxDir = idxDir + 1;
        rootDirs{idxDir} = fullfile(sessionDir(m).folder,sessionDir(m).name);
    end; clearvars m;
end; clearvars n;

rootDirs = rootDirs(contains(rootDirs,{'Absamann'})); % Buchinger, Clementi

% OR in case you have several databases:
% rootDirs = {'E:\OSS1\', ...
% 'E:\OSS2\', ...
% 'E:\OSS3\', ...
% 'E:\OSS4\', ...
% 'E:\OSS5\', ...
%% 
% 'E:\OSS6\', ...
% 'E:\OSS7\'};


for j = 1 : length(rootDirs)

    %% ========================================================================
    % User Settings - make your choices =======================================
    % =========================================================================
    
    %% ===== Before you start the first time ==================================

    % Set the current root directory
    rootDirectory = rootDirs{j}; % The root folder populating all of your working directories
    
    % Consider to run this function once on your rootDirectory to eliminate any
    % special characters in your database paths that might raise errors during
    % COMAK processing! NOTE: this only has to be done once, you then should
    % use the updated pathnames for your workingDirectories in the next
    % section!    
    renameFolders(rootDirectory, {',', ' ','(',')'}); % <--- uncomment if needed!

    %% ===== Set the data to process ==========================================

    % Select Option 1 out of 3:
    Option = 1; % default = 1 (in case you onyl want to process a single folder); Otherwise run case 2 once and afterwards always case 3.

    switch Option
        case 1
            %----- Option #1 ----------------------------------------------------------
            % Set manual list of workingDirectories and staticC3dFiles:
            % You can only specify one single folder. These folders contain all *.c3d files to analyze for a single subject
            % OpenSim automatically looks for that folder here. If not found in workingDirectory\Geometry, it will look at the standard OpenSim Paths.
            % Make sure that all paths have a '\' at the end!
            %---
            workingDirectories = {fullfile(rootDirectory,['Cuttingsession_2','\'])}; % {'D:\...\', 'C:\...\', ...} or {'D:\....\'}
            staticC3DFiles = dir(fullfile(rootDirectory,'Staticandfunctionalsession',['Static','*.c3d']));
            staticC3dFiles = {fullfile(staticC3DFiles(1).folder,staticC3DFiles(1).name)}; % {'Static01.c3d', 'Static.c3d', ...} or {'Static01.c3d'}
        case 2
            %----- Option #2 ----------------------------------------------------------
            % Create workingDirectories and staticC3dFiles automatically and store a local file in the rootDirectory for later usage.
            % If the following line is uncommented it will create the lists of <workingDirectories> and <staticC3dFiles>
            % automatically based on the specified string pattern, e.g., 'Static' or 'Stand', etc.
            % You can choose between two methods: 'byC3dFilePatternName' == looking for the appropriate file by the c3d file name pattern provided by the last
            % inputvar (e.g., 'static') OR by 'byEnfDescription' which will look for the file based on the description in the *.enf file. The latter is the standard for the OSS.
            % Note that the third input is a string pattern for which the script would look at the end of potential static trials, i.e. "A" for "StandA" trials.
            %---
            [workingDirectories, staticC3dFiles] = getTopLvlFoldersStatics(rootDirectory,...
                'byC3dFilePatternName', 'Static', ''); % default (OSS only!) = 'byEnfDescription', 'Stand', '';  default (general) = 'byC3dFilePatternName', 'Static', '';

        case 3
            %----- Option #3 ----------------------------------------------------------
            % Read [workingDirectories, staticC3dFiles] from local file which was
            % created either manually or by Option #2 in an earlier stage. You can
            % specify here from which index it should start. This is the best option for large-scale simulation tasks.
            %---
            startIdx = 1; % default = 1
            stopIdx = NaN; % default = NaN (== to last wd); you can also specify a stop index here.
            [workingDirectories, staticC3dFiles] = readWDsFromFile(rootDirectory, startIdx, stopIdx);

    end

    % Rename all c3d files based on their descriptions in the *.enf files?
    % If there is no Description, files will be changed to NoEnfDescriptionFound_X.Trial.enf
    renameC3DFiles2enfDescription = false; % default (OSS only!) = true; otherwise false

    % Define type of files; For mSEBT directions: AT - PM - PL (these need to be the definitions from the *.enf files!)
    % This string is used to filter all potential found *.c3d files in a
    % directory and is based on the actual file name of each *.c3d.
    conditions =  {'Cutting Left','Cutting Right'}; % {'mSEBT_AT','mSEBT_PM','mSEBT_PL'} or {'WalkA'} or {'Dynamic'}; default (OSS only!) == 'WalkA'
    % % ,'Gait','Running','Counter-Movement Jump','Counter-Movement Jump Left','Counter-Movement Jump Right',...
    %    'Drop Jump Bilateral','Single-Leg Jump Left','Squatting','Squatting Left'

    %% ===== Simulation Settings ==============================================

    %----- Generic Spline -----------------------------------------------------
    % Use "generic secondary constrain splines" instead to compute the splines
    % for each subject? If, yes this will speed up the simulations, the chances
    % of errors during the sec. constrain simulations are eliminated, and it should not make
    % relevant differences as long you use the generic knee model.
    % NOTE: if you use a personalized *.stl knee model you should run this simulation!
    useGenericSplines = true; % default = true; true or false

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
    bodyheightGenericModel = 1650;          % in mm; for the comak Model this is 1650 mm
    scaleMuscleStrength = 'manually';    % default = 'height2pow2', height2pow3, 'No', 'manually', 'HeightSquared'
    manualMusScaleF = 3;                    % default = 0, jh (10.11.2025)

    %%----- Lock Suptalar Joint -----------------------------------------------
    % Lock Subtalar for scaling? This might be usefull if you only have one
    % marker on the forefoot to force a footflat position before markers are
    % replaced during scaling.
    lockSubtalar4Scaling = true; % default = true; true or false

    %%----- Scale Pelvis Manually ---------------------------------------------
    % If yes, the pelvis width will be fetched from the *.mp file and the
    % variable "InterAsisDistance" and used to scale the pelivs manually.
	% While you have this option, our results showed using the standard scaling 
	% based on the HJC seems to be the more accurate approach.
    pelvisWidthGenericModel = 289;  % ASIS-ASIS in mm
    scalePelvisManually = false;    % default = true; or false.

    %%----- Use Automatic Scaling Tool AST? -----------------------------------
    %Do you want to use the The Automated Scaling Tool (AST) to automate the
    % OpenSim Scaling process. It achieves this by iteratively adjusting
    % virtual markers to evaluate the root mean square error (RMSE) and maximum
    % marker error, taking corrective actions until the desired accuracy
    % is reached. See: https://doi.org/10.1016/j.compbiomed.2024.108524

    % NOTE: not yet recommended, results are still questionable.
    useASTool = false; % default = false; true or false;

    %%----- Time Normalization ------------------------------------------------
    % Normalize to 100% activity time (e.g. gait cycle). As of today I do think this only affects the JAM setup file
    timeNorm = 'false'; % default = 'true'; 'true' or 'false'

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
    useStatic4FrontAlignmentAsFallback = false;         % default = false; true or false
    tf_angle_fromSource = 'false';                      % default = 'false'; 'false', 'fromStatic', 'fromExtDataFile', 'manual'
    tf_angle_r = 0;                                     % default = 0
    tf_angle_l = 0;                                     % default = 0


    %%----- Torsion Tool ------------------------------------------------------
    % Define if you want to use the TorsionTool by Veerkamp et al. (2021) to personalize the tibial torsion, femur anteversion, and neckshaft angle.
    % These valus are derived from a "data.xml" (see example data) located next to your *.c3d files. Or you can use the "useDirectKinematics4TibRotEstimationAsFallback"
    % to use the angle based on the direct kinematics data from the dynamic c3d files (median knee rot. during stance for all gait cycles of all trials) in case the TT information is not available from the external file.
    % You can also directly specifiy to use the direct kinematics data from the dynamic c3d files as TT value for the TorsionTool.
    % NOTE: before using the TorsionTool check the hardcoded default values in the main torsion script, since based on these the torsion will be adjusted accordingly!
    % NOTE to 'fromStatic' - we currently use the CleveLand Model (from OSS - Speising). Here external TT is NEGATIVE. Currently this values is multiplied by -1 to have the correct sign for the TorsionTool (where ext. TT is POSITIVE).
    useDirectKinematics4TibRotEstimationAsFallback = false;         % default = false; true or false;
    tibTorsionAdaptionMethod = 'fromStatic';                        % default = 'fromStatic'; 'fromExtDataFile' or 'fromStatic'
    tibTorsionAdaption = false;                                     % default = false; true or false
    neckShaftAdaption = false;                                      % default = false; true or false
    femurAntetorsionAdaption = false;                               % default = false; true or false

    %%----- Check & Adapt Wrapping Objects ------------------------------------
    % Decide whether you want to automatically check and adapt discontinuities in
    % the moment arms. If true the scaled model will be checked for
    % discontinuities in moment arms at the hip and knee and wrapping objects will be iteratively
    % reduced until discontinuities are resolved. This script is based on Willi
    % Kollers (unpublished) work.
    checkAndAdaptMomArms = false; % default = true; true or false

    %%----- Contact Energy ----------------------------------------------------
    % Specify COMAK settings, Contact Energy and Muscle Weight
    contactE = 0; % default = 100; value of Contact Energy weighting, e.g. 0 - ~500; 100-150 seem reasonable and reduce the 2nd KJCF peak reasonable in my experiments
    MW = 'false'; % 'true' or 'false'. Weights are predefined in setting files. default = 'true' (see Colin Smith, <add here>)

    %%----- Contact Geometry --------------------------------------------------
    % Define which bodypart has first contact to ground (e.g. for generating the external loads file)
    firstContact_L = 'calcn_l'; % default = 'calcn_l'
    firstContact_R = 'calcn_r'; % default = 'calcn_r'

    %%----- Pelvis Helper Marker ----------------------------------------------
    % Do you want to add pelvis helper marker to, e.g., allow for non-uniform scaling
    % of the pelvis? If yes, toggle to true. Note: you will manually need to
    % set the scaling to non-uniform in the scale setup file! Settings this to
    % true only adds the markers to the static *.trc file.
    addPelvisHelperMarker = false; % default = true; true or false

    %%----- Create *.MOT and *.TRC Files --------------------------------------
    % Do you want to create *.trc and *.mot files automatically using the built-in code? If so, set to true. Note that
    % this will always overwrite any existing *.trc and *.mot files! If set to
    % false and no files are available an error will be raised.
    forceTrcMotCreation = true; % default = true

    %%----- Prefix ------------------------------------------------------------
    % Add file-prefix to distinguish different setups, for example to indicate a specfic trial 'variation', e.g. 'with_muscle_optimization'
    % Note: for convenience during group analysis it is recommended to always use a prefix!
    % Note always separate prefix conditions with '-' (standard-CE150). Do not use an '_'! Otherwise it will not work.
    prefix = 'lig5-sgf1000'; % default = 'standard', or e.g. 'noTimeNorm', 'VarAligned2deg'

    %%----- Data Augmentation -------------------------------------------------
    % Data Augmentation-Mode. If you set this to true, each trial will be run
    % on a set of models adapted on predefined varus-valgus-tib-rotation sets. Note that the
    % prefix will be auto-generated based on the augmentation settings
    dataAugmentation = false; % default = false; true or false

    %%----- Generate new models -----------------------------------------------
    % Force Model Creation? If set to true, the workflow will always scale and
    % generate a new model. Otherwise, a model will be only created if no appropriate models are found.
    ForceModelCreation = true; % default = true; true or false

    %%----- Allow autorestart of Matlab ---------------------------------------
    % This function might be helpful for large-scale simulation studies and if
    % Matlab faces a memory leak, where the RAM blocked by Matlab consistently
    % increases until fully used. This will cause Matlab to crash. If the user
    % selects <true>, the workflow will check regularily for free RAM and in case
    % it detects RAM gets low, it will save the current workspace at the end of
    % a WD loop, restart matlab, and proceed with its simulations. This should
    % clear any RAM blocked by the memory leak of Matlab. Further you can
    % also set <iterationCntRestart> to force a restart if the iteration loop reaches
    % the set threshold. 
    allowAutoRestart = false; % default = false; true or false
    iterationCntRestart = 500; % default = 500; to turn this off, set to e.g. 999999 
    thresholdFreeRAM = 20; % default = 10; in percentaged of available RAM;

    %% ===== PostProcessing Settings ==========================================

    %%----- Postprocessing Y/N? -----------------------------------------------
    % Run the standard postprocessing workflow automatically directly afterwards for the rootDirectory and the specified prefix?
    % Note: this is not recommend for large-scale simulations. This will be
    % significantly slower than running post processing afterwards.
    performPostProcessing = false; % default = true; true or false

    %%----- Time Normalize Results? -------------------------------------------
    % Force to time normalize all data to 100% activity time OR use settings from JAM
    % processing. Note that the latter migth return partly time-normalized data (for
    % joint contact force and non-normalized ones for e.g. muscle activity.
    timeNormFlag = true; % default = true; true or false;

    %%----- Specify Type of Trials --------------------------------------------
    % Set trial type for plotting: walking or not "something else" (=notWalking)
    % This is only necessray to have the plots nicely formatted.
    trialType = 'notWalking'; % default = 'walking'; 'walking' or 'notWalking';

    %% ===== COMAK Processing Settings ========================================

    %%----- Write *.vtp files? ------------------------------------------------
    % Decide if the JAM processing should create all *.vtp files. This takes a
    % lot of harddisc space but is the default and necessary if you want to use
    % Paraview 5.5.2 to view the 3D mesh files and inspect loads.
    % NOTE: the post processing pipeline will not work if you do not write the
    % *.vtp files!
    writeVtp = false; % default = true; true or false

    %%----- Which *.vtp files to write? ---------------------------------------
    % Here you can specify which *.vtp files should be created. This can save
    % a considerably amount of processing time and hard disc space!

    % Either specify a certain set here or simply 'all' or 'none'
    ligaments = ...
        ['/forceset/ACLpl1 /forceset/ACLpl2 /forceset/ACLpl3 /forceset/ACLpl4 /forceset/ACLpl5 /forceset/ACLpl6' ...
        ' /forceset/ACLam1 /forceset/ACLam2 /forceset/ACLam3 /forceset/ACLam4 /forceset/ACLam5 /forceset/ACLam6' ...
        ' /forceset/PCLal1 /forceset/PCLal2 /forceset/PCLal3 /forceset/PCLal4 /forceset/PCLal5' ...
        ' /forceset/PCLpm1 /forceset/PCLpm2 /forceset/PCLpm3 /forceset/PCLpm4 /forceset/PCLpm5'];

    % Either specify a certain set here or simply 'all' or 'none'
    attachedGeometryBodies = '/bodyset/femur_distal_# /bodyset/patella_# /bodyset/tibia_proximal_#'; % Note the '#' as a placeholder for 'r' or 'l' (right/left)

    %%----- Set Lab  ----------------------------------------------------------
    % Define from which lab the data come from
    labFlag = 'PLUS_SportsMarkerset_noArms_newFPs'; % PLUS_SportsMarkerset_noArms', 'OSS', 'OSSnoArms', 'FHSTP-BIZ', 'FHSTP', 'FHSTPnoArms', 'ISW', 'LKHG_Cleve', 'LKHG_PiG'

    %%----- Set max. N of cmd windows -----------------------------------------
    % Define number of allowed simultaneously running cmd windows.
    maxCmd = 8; % default = 8 (for a Surface Book2 @i7-8650U @ 1.90Ghz), 31 for 32-core Server

    %%----- CPU Load Threshold ------------------------------------------------
    % Define a threshold the CPU-load has to fall below (median over 1 minutes), before the next batch of files are forwarded to the cmd window.
    % In case this is set to False the workflow will use the amount of open cmd windows to control CPU load. Here the above threshold <maxCmd> will be used as cut-off.
    thresholdCpuLoad = 40;      % default ~ 40% for Laptop, ~70% for 64-core Server
    useCPUThreshold = false;    % default = false; true or false

    % NOTE: it seems that the function <CpuLoadBasedPausing> & <CpuLoadBasedPausing_WIN11> does not always work properly for WIN11 and
    % newer Intelchips (intel core Ultra 7). Therefore the the appraoch using the amount of open cmd windows is recommended.

    %%----- Catch errors Y/N? -------------------------------------------------
    % Disable this for debugging when developing the code. Enable for running
    % big file batches so that errors are caught and Matlab won`t stop on an
    % error.
    catchErrors = true; % default = true; true or false

    %%----- Delete some *.vtp files (deprecated) ------------------------------
    % Select if all unnecessary *.vtp files should be deleted. Note that this
    % is a very slow process ... for two trials it takes about 13 minutes. I
    % recommend to do that in a separate step. Rather than using this function
    % consider to use the function above: "Which *.vtp files to write?"
    deleteVtps = false; % default = false; true or false

    % Files to keep
    vtp2keep = {'femur_cartilage', 'tibia_cartilage', 'patella_cartilage', 'femur_bone', 'tibia_bone', 'patella_bone', 'ACL', 'PCL'};


    %% ========================================================================
    % HARDCODED Settings ======================================================
    % =========================================================================    
    
    % Implemented marker sets and some settings based on the markersets
    switch labFlag
        case {'OSSnoArms', 'FHSTPnoArms'}
            % Cleve comak marker set withou arms
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
            tib_torsion_LeftMarkers = {'LKNE', 'LKJC', 'LANK', 'LAJC'};
            tib_torsion_RightMarkers = {'RKNE', 'RKJC', 'RANK', 'RAJC'};

        case {'OSS', 'FHSTP-BIZ', 'FHSTP'}
            % Cleve comak marker set full body
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
            tib_torsion_LeftMarkers = {'LKNE', 'LKJC', 'LANK', 'LAJC'};
            tib_torsion_RightMarkers = {'RKNE', 'RKJC', 'RANK', 'RAJC'};

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
            tib_torsion_LeftMarkers = {'LKNE', 'LMKNE', 'LANK', 'LMMA'};
            tib_torsion_RightMarkers = {'RKNE', 'RMKNE', 'RANK', 'RMMA'};

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
            tib_torsion_LeftMarkers = {'LKNE', 'LKNM', 'LANK', 'LANM'};
            tib_torsion_RightMarkers = {'RKNE', 'RKNM', 'RANK', 'RANM'};

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

        case {'PLUS_COD_noArms'}
            % Markerset of the Change of direction study of Gunter Kurz
            markerSet = {'head_front_left','head_front_right', 'head_back_right', 'head_back_left', 'C7', 'B10', 'CLAV', 'acrom_left', ... % Huthöfer: Markerset from Salzburg
                'acrom_right', ...
                'SIPS_left', 'SIPS_right', 'SIAS_left', 'SIAS_right', 'LTHI', 'LTHI1', 'LTHI2', 'LTIB2', 'LTIB', 'LTIB1', ... 
                'mal_lat_left', 'mal_med_left', 'cal_back_left', 'forefoot_med_left', 'toe2_left', 'forefood_lat_left', 'RTHI1', 'RTHI', 'RTHI2', 'RTHI3',...
                'epi_med_right', 'epi_lat_right', 'epi_med_left', 'epi_lat_left', 'RTIB', 'RTIB2', 'RTIB1', 'mal_lat_right', 'mal_med_right', 'cal_back_right', 'toe_right', 'toe2_right', 'forefood_lat_right', ...
                'forefoot_med_right', 'toe_left', 'sternum'};
            % markerSet = {'head_front_left', 'head_front_right', 'head_back_right', 'head_back_left','acrom_right', 'acrom_left', 'C7', 'CLAV', 'B10', 'sternum', 'SIPS_right', 'SIPS_left', 'SIAS_left', 'SIAS_right', 'LTHI1', 'LTHI', 'LTHI2', 'epi_med_left', 'LTIB1', 'LTIB', 'LTIB2', 'mal_lat_left', 'mal_med_left', 'cal_back_left', 'forefood_lat_left', 'toe2_left', 'forefoot_med_left', 'toe_left', 'RTHI', 'RTHI2', 'RTHI3', 'epi_med_right', 'RTIB1', 'RTIB', 'RTIB2', 'mal_lat_right', 'mal_med_right', 'cal_back_right', 'forefood_lat_right', 'toe2_right', 'forefoot_med_right', 'toe_right', 'LUPA', 'Elbow_lat_left', 'Elbow_med_left', 'hand_lat_left', 'hand_med_left', 'hand_top_left', 'RUPA', 'hand_lat_right', 'hand_med_right', 'hand_top_right'};
            % The markers used for the appendHelperMarkers function for the nonuniform pelvis scaling.
            % Note: they always have to have the following order: {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'} or {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSI', 'RPSI'}!
            pelvisMarker4nonUniformScaling = {'SIPS_left', 'SIPS_right', 'LHJC', 'RHJC', 'SIAS_left', 'SIAS_right'}; % Huthöfer: SIAS and SIPS are intentionally the other way around as student assistents did this name mistake in the very beginning

            % Markers used to calculate the tibial torsion
            tib_torsion_LeftMarkers = {'LKNE', 'LKJC', 'LANK', 'LAJC'}; % Huthöfer: not needed
            tib_torsion_RightMarkers = {'RKNE', 'RKJC', 'RANK', 'RAJC'}; % Huthöfer: not needed

        case {'PLUS_SportsMarkerset_noArms','PLUS_SportsMarkerset_noArms_newFPs'}
            % Holder: SportsMarkerset from Salzburg
            markerSet = {'HeadL','HeadR','HeadFront',...
                'Chest','SpineThoracic2','SpineThoracic12','LShoulderTop','RShoulderTop',...
                'WaistLFront','WaistL','WaistBack','WaistR','WaistRFront',...
                'LThighFrontLow','LKneeOut','LKneeIn','LShinFrontHigh',...
                'LAnkleOut','LHeelBack','LForefoot5','LForefoot2',...
                'RThighFrontLow','RKneeOut','RKneeIn','RShinFrontHigh',...
                'RAnkleOut','RHeelBack','RForefoot5','RForefoot2'};
    %             'LTroch','LAnkleIn','LHJC','LKJC','LAJC',...
    %             'RTroch','RAnkleIn','RHJC','RKJC','RAJC',...
            % The markers used for the appendHelperMarkers function for the nonuniform pelvis scaling.
            % Note: they always have to have the following order: {'LASI', 'RASI', 'LHJC', 'RHJC', 'SACR'} or {'LASI', 'RASI', 'LHJC', 'RHJC', 'LPSI', 'RPSI'}!
            pelvisMarker4nonUniformScaling = {'WaistLFront','WaistRFront', 'LHJC', 'RHJC','WaistBack'};

            % Markers used to calculate the tibial torsion
            tib_torsion_LeftMarkers = {'LKneeOut', 'LKJC', 'LAnkleOut', 'LAJC'}; 
            tib_torsion_RightMarkers = {'RKneeOut', 'RKJC', 'RAnkleOut', 'RAJC'};

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

    % Create struct for JAM settings
    jamSettings.ligaments = ligaments;
    jamSettings.attachedGeometryBodies = attachedGeometryBodies;

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

    %% Run COMAK processing
    disp('*********************************************  prepare COMAK  **********************************************');

    % Run the workflow
    loops4Comak(rootDirectory, workingDirectories, staticC3dFiles, conditions, labFlag, path2GenericModels, path2bin, path2opensim, path2setupFiles, tf_angle_r, tf_angle_l, ...
        firstContact_L, firstContact_R, contactE, MW, prefixCell, timeNorm, maxCmd, thresholdCpuLoad, catchErrors, writeVtp, useGenericSplines, lockSubtalar4Scaling, ...
        scaleMuscleStrength, manualMusScaleF, markerSet, bodyheightGenericModel, addPelvisHelperMarker, pelvisMarker4nonUniformScaling, tf_angle_fromSource, torsiontool, useDirectKinematics4TibRotEstimationAsFallback, ...
        tib_torsion_LeftMarkers, tib_torsion_RightMarkers, forceTrcMotCreation, dataAugmentation, ForceModelCreation, performPostProcessing, trialType, timeNormFlag, renameC3DFiles2enfDescription, ...
        vtp2keep, deleteVtps, jamSettings, checkAndAdaptMomArms, useASTool, repoPaths, allowAutoRestart, thresholdFreeRAM, useC3Devents, scalePelvisManually, pelvisWidthGenericModel, ...
        useStatic4FrontAlignmentAsFallback, tibTorsionAdaptionMethod, useCPUThreshold, varNameKneeAngle_c3d, iterationCntRestart)

    %% Final  message
    disp('*******************************************  COMAK over and out  *******************************************');
end