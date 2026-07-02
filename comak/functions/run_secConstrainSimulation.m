function [secondary_constraint_function_file, second_constraints, secondary_coupled_coordinate] = run_secConstrainSimulation(workingDirectory, path2bin, path2opensim, path2SetupFiles, side, path2trc, path2mot, path2scaledModel, IC, ICi, prefix, tf_angle, labFlag, useGenericSplines)
% -------------------------------------------------------------------------
% This function will run the sec. constrain simulation and stores the
% output in the root folder of the working directory. Note that the comak
% inverse-kinematics will be performed later and not in this function.
%
%
%
%
% Written by:           Brian Horsak - brian.horsak@fhstp.ac.at
% Acknowledgements:     Many thx to Bryce Killian (KU Leuven) for his great
%                       support
%
% Last changed:         03/2023
% -------------------------------------------------------------------------

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  USER SETTINGS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Visualize tasks during processing
vis_secCon = 'true';

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Some housekeeping variables %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch labFlag

    case 'ISW'
        path2SpecificSetupFiles = fullfile(path2SetupFiles,'Models\ISW\');

    case {'OSS', 'FHSTP-BIZ', 'FHSTP'}
        path2SpecificSetupFiles = fullfile(path2SetupFiles,'Models\OSS_FHSTP\');
    
    case {'OSSnoArms', 'FHSTPnoArms'}
        path2SpecificSetupFiles = fullfile(path2SetupFiles,'Models\OSS_FHSTPnoArms\');

    case 'LKHG_Cleve'
        path2SpecificSetupFiles = fullfile(path2SetupFiles,'Models\LKHG_Cleve\');
    
    case 'LKHG_PiG'
        path2SpecificSetupFiles = fullfile(path2SetupFiles,'Models\LKHG_PiG\');

    case 'PLUS_COD_noArms'
        path2SpecificSetupFiles = fullfile(path2SetupFiles,'Models\PLUS_COD_noArms\');
        
    case {'PLUS_SportsMarkerset_noArms','PLUS_SportsMarkerset_noArms_newFPs'}
        path2SpecificSetupFiles = fullfile(path2SetupFiles,'Models\_PLUS_pilotMC_noArms\');
end

% Set some necessary paths
% Paths to this repository (setup files and opensim executable)
path.bin = path2bin;
path.opensim = path2opensim;
path.setupFiles = path2SpecificSetupFiles;
path.trc = path2trc;
path.mot = path2mot;
path.scaledModel = path2scaledModel;
side = lower(side); % make "side" lower case so that it matches the if clause

%% Set working directory to path where the walking files are stored
%[~,file,~] = fileparts(path.trc);
%str = regexp(path.trc, file);
%path.workingDirectory = path.trc(1:str(end)-1);

% Change current folder to working directory
cd(workingDirectory);

%% Create COMAK input and results folder and Copy setupFiles in working directory
% Add folders to path
path.COMAKsecSimResults = strcat(workingDirectory,'JAM\');

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% COMAK - sec constrain simulation ONLY %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Copy generic sec. constrain spline to folder if user seletced to do so
if useGenericSplines
    copyfile(fullfile(path2SetupFiles, 'Models','generic_IK_second_coord_constraint_functions_left.xml'), fullfile(workingDirectory,'JAM','generic_IK_second_coord_constraint_functions_left.xml'));
    copyfile(fullfile(path2SetupFiles, 'Models','generic_IK_second_coord_constraint_functions_right.xml'), fullfile(workingDirectory,'JAM','generic_IK_second_coord_constraint_functions_right.xml'));

    % Prepare output file name
    IK_secCoordFunctionName = strcat('generic_IK_second_coord_constraint_functions_', side,'.xml');
    xmlFile = strcat(path.COMAKsecSimResults, side, '_secConstrainSimulation_settings_tmpFile.xml');

    % Copy setup file if not existing
    if ~logical(exist(xmlFile, 'file'))
        copyfile(strcat(path.setupFiles,'ComakSetUpFiles\1_comak_inverse_kinematics_settings.xml'), xmlFile);
    end

    % Create name part for bat file
    batFilePart_tf = '-standard-genericSplines';
    
else
    % Change name to var/valg adaption
    if tf_angle == 0

        % Or prepare standard output file name
        IK_secCoordFunctionName = strcat('IK_second_coord_constraint_functions_', side,'.xml');
        xmlFile = strcat(path.COMAKsecSimResults, side, '_secConstrainSimulation_settings_tmpFile.xml');

        % Copy setup file if not existing
        if ~logical(exist(xmlFile, 'file'))
            copyfile(strcat(path.setupFiles,'ComakSetUpFiles\1_comak_inverse_kinematics_settings.xml'), xmlFile);
        end

        % Create name part for bat file
        batFilePart_tf = '-standard';

    elseif tf_angle > 0 % varus adapted

        % Prepare output file name
        IK_secCoordFunctionName = strcat('IK_second_coord_constraint_functions_', side, '-tf_varus_adapted_', num2str(abs(tf_angle)) ,'.xml');
        xmlFile = strcat(path.COMAKsecSimResults, side, '_secConstrainSimulation_settings-tf_varus_adapted_', num2str(abs(tf_angle)) ,'.xml');

        % Copy setup file if not existing
        if ~logical(exist(xmlFile, 'file'))
            copyfile(strcat(path.setupFiles,'ComakSetUpFiles\1_comak_inverse_kinematics_settings.xml'), xmlFile);
        end
        % Create name part for bat file
        batFilePart_tf = strcat('-tf_varus_adapted_', num2str(abs(tf_angle)));

    elseif tf_angle < 0 % valgus adapted

        % Prepare output file name
        IK_secCoordFunctionName = strcat('IK_second_coord_constraint_functions_', side, '-tf_valgus_adapted_', num2str(abs(tf_angle)) ,'.xml');
        xmlFile = strcat(path.COMAKsecSimResults, side, '_secConstrainSimulation_settings-tf_valgus_adapted_', num2str(abs(tf_angle)) ,'.xml');

        % Copy setup file if not existing
        if ~logical(exist(xmlFile, 'file'))
            copyfile(strcat(path.setupFiles,'ComakSetUpFiles\1_comak_inverse_kinematics_settings.xml'), xmlFile);
        end

        % Create name part for bat file
        batFilePart_tf = strcat('-tf_valgus_adapted_', num2str(abs(tf_angle)));
    end
end

switch side
    case 'right'
        % Check if a '_IK_second_coord_constraint_functions_.xml' file is available 
        if logical(exist(strcat(workingDirectory,'JAM\',IK_secCoordFunctionName), 'file'))
            changeXML(xmlFile,'perform_secondary_constraint_sim','false',1);
            run_secConSim = 'false'; % this is needed to decide if bat should be run in cmd window or in matlab system
        else
            changeXML(xmlFile,'perform_secondary_constraint_sim','true',1);
            run_secConSim = 'true'; % this is needed to decide if bat should be run in cmd window or in matlab system
        end

        % Define constraints
        second_constraints = (['/jointset/knee_r/knee_add_r /jointset/knee_r/knee_rot_r /jointset/knee_r/knee_tx_r ' ...,
            '/jointset/knee_r/knee_ty_r /jointset/knee_r/knee_tz_r ' ...,
            '/jointset/pf_r/pf_flex_r /jointset/pf_r/pf_rot_r /jointset/pf_r/pf_tilt_r ' ...,
            '/jointset/pf_r/pf_tx_r /jointset/pf_r/pf_ty_r /jointset/pf_r/pf_tz_r']);
        changeXML(xmlFile,'secondary_coordinates',second_constraints,1);

        secondary_coupled_coordinate = '/jointset/knee_r/knee_flex_r';
        changeXML(xmlFile,'secondary_coupled_coordinate',secondary_coupled_coordinate,1);

        % Define name of output file for right
        secondary_constraint_function_file = strcat(workingDirectory,'JAM\', IK_secCoordFunctionName);

    case 'left'
        % Check if a '_IK_second_coord_constraint_functions_.xml' file is available 
        if logical(exist(strcat(workingDirectory,'JAM\',IK_secCoordFunctionName), 'file'))
            changeXML(xmlFile,'perform_secondary_constraint_sim','false',1);
            run_secConSim = 'false'; % this is needed to decide if bat should be run in cmd window or in matlab system
        else
            changeXML(xmlFile,'perform_secondary_constraint_sim','true',1);
            run_secConSim = 'true'; % this is needed to decide if bat should be run in cmd window or in matlab system
        end

        % Define constraints
        second_constraints = (['/jointset/knee_l/knee_add_l /jointset/knee_l/knee_rot_l /jointset/knee_l/knee_tx_l ' ...,
            '/jointset/knee_l/knee_ty_l /jointset/knee_l/knee_tz_l ' ...,
            '/jointset/pf_l/pf_flex_l /jointset/pf_l/pf_rot_l /jointset/pf_l/pf_tilt_l ' ...,
            '/jointset/pf_l/pf_tx_l /jointset/pf_l/pf_ty_l /jointset/pf_l/pf_tz_l']);
        changeXML(xmlFile,'secondary_coordinates',second_constraints,1);

        secondary_coupled_coordinate = '/jointset/knee_l/knee_flex_l';
        changeXML(xmlFile,'secondary_coupled_coordinate',secondary_coupled_coordinate',1);

        % Define name of output file for left
        secondary_constraint_function_file = strcat(workingDirectory,'JAM\', IK_secCoordFunctionName);
end

% Change xml nodes
changeXML(xmlFile,'model_file',path.scaledModel,1); % I only need to change the first node here, because the IK is not run at this moment.
changeXML(xmlFile,'results_directory',path.COMAKsecSimResults,2); % Note: this changes two nodes at once because they are named identically
changeXML(xmlFile,'results_prefix',' ',1); % Use a space, because empty strings will let the xml node break during parsing
changeXML(xmlFile,'perform_inverse_kinematics','false',1); % Default 'false' only here in run sec constrain sim only script!
changeXML(xmlFile,'secondary_coupled_coordinate_stop_value','120',1); % default = 120
changeXML(xmlFile,'secondary_constraint_function_file',secondary_constraint_function_file,1);
changeXML(xmlFile,'constrained_model_file',strcat(path.scaledModel),1); % add constrained model
changeXML(xmlFile,'marker_file','Unassigned',1);
changeXML(xmlFile,'time_range','0 0',1);
changeXML(xmlFile,'output_motion_file',' ',1); % Use a space, because empty strings will let the xml node break during parsing
changeXML(xmlFile,'use_visualizer',vis_secCon,1);
changeXML(xmlFile,'verbose','2',1); % 0: low, 1: medium, 2: high

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Write *.bat file and execute it %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Run COMAK - sec constrain simulation ONLY
% Copy bin and opensim folder to working directory
if ~logical(isfolder(fullfile(workingDirectory,'bin')))
    copyfile(path.bin, fullfile(workingDirectory,'bin'));
end
if ~logical(isfolder(fullfile(workingDirectory,'opensim')))
    copyfile(path.opensim, fullfile(workingDirectory,'opensim'));
end

% Set environment
strPaths = 'REM Let Windows know where the plugin and opensim libraries are';
line1 = 'set BIN=%CD%\..\bin';
line2 = 'set OPENSIM=%CD%\..\opensim';
line3 = 'set PATH=%BIN%;%OPENSIM%;%PATH%';

% Run system command similar to the batch file
strCOMAK_secConSim = 'REM COMAK - sec constrain simulation ONLY';
line4 = (['%BIN%\comak-inverse-kinematics',' ', '%BIN%\jam_plugin.dll', ' ', xmlFile]);
line5 = ''; %(['move out.log',' ', path.COMAKsecSimResults, [trialInfo.fileName,'_comak-IK_out.txt']]);
line6 = ''; %(['move err.log',' ', path.COMAKsecSimResults, [trialInfo.fileName,'_comak-IK_err.txt']]);
line_end = ''; % exit - this does not work

% Write bat file to subject folder
batFilePart = strcat('runSecConstrainSimOnly', batFilePart_tf);
batFilePath = strcat(path.COMAKsecSimResults,side,'_',batFilePart,'.bat');
fid = fopen(batFilePath,'wt');
fprintf(fid, '%s\n%s\n%s\n%s\n\n%s\n%s\n%s\n%s\n%s', ...
    strPaths,line1, line2, line3, strCOMAK_secConSim, line4, line5, line6, line_end);
fclose(fid);

%% Execute *.bat file in cmd
cd(path.COMAKsecSimResults);

if strcmp(run_secConSim, 'true')
    eval(strcat('!', batFilePath,' &'));  % '&' give the comand back to matlab and run next cmd window
    %system(batFilePath);
    disp(string(strcat('>>>>> COMAK sec. constrain simulation for', {' the '}, side, {' side '}, 'forwarded to cmd window.')));    
else
    disp('>>>>> Existing sec. constr. simulation found! ****');
end

%% Clear variables except output to prevet memory leak.
clearvars -except secondary_constraint_function_file second_constraints secondary_coupled_coordinate
end