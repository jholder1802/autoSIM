function Model_workflow(workingDirectory, path2opensim, path2setupFiles,  side, filename, path2trc, path2mot, path2extLoad, path2scaledModel, IC, cTO, cIC, TO, ICi, BW, prefix, tf_angle_r, tf_angle_l, labFlag, Model2Use, tasks)
% -------------------------------------------------------------------------
% This function will run the selected model in Matlab. Several
% changes to the *.xml settings files can be made within this script.
%
% Tested on Matlab 2019b and Windows 10
%
% INPUT:
% side: string, e.g. 'right' or 'r'
% filename: string, name of the file without file extension, e.g. 'walk01'
% path2trc: full path to the *.trc file
% path2mot: full path to the *.mot file
% path2extLoad: full path to the ext. loads file
% path2scaledModel: full path to the scaled model (*.osim)
% IC: start time in seconds of time series (this should be initial contact)
% cTO: toe-off in seconds of cont. lat. side
% cIC: contralateral toe-off
% TO: toe-off  in seconds of ipsi lateral side
% ICi: end time in seconds of time series (this should be ipsi lateral IC)
% BW: body weight, e.g. 95 kg * 9.81 m/s^2
% prefix: string, prefix used for naming, e.g. 'test_'; leave blank if not
% used
% tf_angle_l / tf_angle_l: angle in degrees used to change frontal knee
% alignment in start script.
% labFlag: string specifiying which lab the data come from
%
%
% Note that ...
%   1) you will need a scaled *.osim model
%   2) not all nodes from the *.xml files are implemented in this script.
%      Please check the setupFiles the first time you use this repository.
%   3) this script expects to get one singel full gait cycle as input
%   4) some of the input variables are unused, but they are saved at the
%      end in a workspace file. This file is loaded later again for data
%      and errror reporting and these currently unused variables will be
%      necessary there.
%
%
% Written by:           Brian Horsak - brian.horsak@fhstp.ac.at
% Acknowledgements:     Many thx to Bryce Killian (KU Leuven) for his great
%                       support
%
% Last changed:         04/2023
% -------------------------------------------------------------------------

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  USER SETTINGS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% ...

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Some housekeeping variables %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Create lab specific paths
% NOTE: to add a new lab you will only need to add it to the switch
% statement. No furtehr changes to the code should be necessary here.

switch labFlag

    case 'ISW'
        path2setupFiles = fullfile(path2setupFiles, [Model2Use, 'Models'],'\ISW\');

    case {'OSS', 'FHSTP-BIZ', 'FHSTP', 'OSS-pyCGM'} % note: since pyCGM just has four more markers RD1M & RD5M, .... this shoudl still work for all OSS-pyCGM and OSS (original).
        path2setupFiles = fullfile(path2setupFiles, [Model2Use, 'Models'],'\OSS_FHSTP\');

    case {'FHSTPnoArms', 'OSSnoArms'}
        path2setupFiles = fullfile(path2setupFiles, [Model2Use, 'Models'],'\OSS_FHSTPnoArms\');

    case 'FHCWnoArms'
        path2setupFiles = fullfile(path2setupFiles, [Model2Use, 'Models'],'\OSS_FHCWnoArms\');

    case {'FHSTP-pyCGM'}
        path2setupFiles = fullfile(path2setupFiles, [Model2Use, 'Models'],'\FHSTP-pyCGM\');

    case {'FHSTP_pyCGM2_5'}
        path2setupFiles = fullfile(path2setupFiles, [Model2Use, 'Models'],'\FHSTP_pyCGM2_5\');
    
    case {'FHSTP_pyCGM2_5noArms'}
        path2setupFiles = fullfile(path2setupFiles, [Model2Use, 'Models'],'\FHSTP_pyCGM2_5_noArms\');

    case {'UMC_HBMnoArms'}
        path2setupFiles = fullfile(path2setupFiles, [Model2Use, 'Models'],'\UMC_HBMnoArms\');

    case 'FF'
        path2setupFiles = fullfile(path2setupFiles, [Model2Use, 'Models'],'\FrankFurt\');

    otherwise
        warning('Unknown labFlag: %s in Model_workflow. Skript paused!', labFlag);
        pause()
end

% Set some necessary paths
% Paths to this repository (setup files and opensim executable)
path.opensim = path2opensim;
path.setupFiles = path2setupFiles;
path.trc = path2trc;
path.mot = path2mot;
path.scaledModel = path2scaledModel;
path.extLoadFile = path2extLoad;
side = lower(side); % make "side" lower case so that it matches the if clause

% Get path where model is stored
idx = strfind(path.scaledModel,'\');
path.data = path.scaledModel(1:idx(end));

% Add "_" to prefix
if ~isempty(prefix); prefix = strcat(prefix,'_'); end

%% Set working directory to path where the walking files are stored
%[~,file,~] = fileparts(path.trc);
%str = regexp(path.trc, file);
%path.workingDirectory = path.trc(1:str(end)-1);
path.workingDirectory = workingDirectory;

% Change current folder to working directory
cd(path.workingDirectory);

%% Set trial info
trialInfo.startTime = IC;
trialInfo.endTime = ICi;
trialInfo.fileName = strcat(prefix, filename, '_', lower(side(1)));
statesFileName = strcat(trialInfo.fileName,'_');

%% Create input and results folder and Copy setupFiles in working directory
% Add folders to path
path.results = strcat(path.workingDirectory,'Simulation\',trialInfo.fileName,'\');
path.input = strcat(path.results, '_input\');

% Now copy files to the new input folder
copyfile(strcat(path.setupFiles,Model2Use,'SetUpFiles\'), path.input);
% Note: Geomtry folder was already copied to the working directory during scaling

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Inverse Kinematics %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if tasks.IK
    %% Prepare setUpFile
    xmlFile = strcat(path.input, 'inverse_kinematics_settings.xml');
    path.OpenSimInverseKinematics = xmlFile;

    % Create folder and set path to inverse-kinematics subfolder
    path.resultsIK = [path.results,'inverse-kinematics\'];
    if ~isfolder(path.resultsIK)
        mkdir(path.resultsIK);
    end

    % Change xml nodes
    changeXML(xmlFile,'model_file',path.scaledModel,1);
    changeXML(xmlFile,'results_directory',path.resultsIK,1);
    changeXML(xmlFile,'marker_file',path.trc,1);
    changeXML(xmlFile,'time_range',[num2str(trialInfo.startTime),' ', num2str(trialInfo.endTime)],1);
    changeXML(xmlFile,'output_motion_file',strcat(path.resultsIK,trialInfo.fileName,'_IK_motion_file.mot'),1);
    changeXML(xmlFile,'report_errors','true',1);
    changeXML(xmlFile,'report_marker_locations','true',1);
end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Residual Reductions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if tasks.RR
    %% Prepare setUpFiles
    path.OpenSimResidualReduction = strcat(path.input, 'residual_reduction_settings.xml');
    path.RRA_actuators = strcat(path.input,'RRA\', Model2Use,'_RRA_Actuators.xml');
    path.RRA_tasks = strcat(path.input,'RRA\', Model2Use,'_RRA_Tasks.xml');

    % Create results folder and set path to RRA subfolder
    path.resultsRRA = [path.results,'residual-reduction\'];
    if ~isfolder(path.resultsRRA)
        mkdir(path.resultsRRA);
    end

    % Adjust COM position in actuator file
    COM = getCOMbody(path.scaledModel, 'pelvis');
    changeXML(path.RRA_actuators,'point',[num2str(COM(1)), ' ',num2str(COM(2)), ' ', num2str(COM(3))],3);

    % Change xml nodes
    if ~isfile(xmlFile); warning('Residual Reductions not implemented yet for this model. Check setup files! Skript paused!'); pause(); end
    xmlFile = path.OpenSimResidualReduction;
    changeXML(xmlFile,'model_file',path.scaledModel,1);
    changeXML(xmlFile,'replace_force_set','true',1);
    changeXML(xmlFile,'force_set_files', path.RRA_actuators,1);
    changeXML(xmlFile,'results_directory', path.resultsRRA,1);
    changeXML(xmlFile,'initial_time', num2str(trialInfo.startTime),1);
    changeXML(xmlFile,'final_time', num2str(trialInfo.endTime),1);
    changeXML(xmlFile,'external_loads_file', path.extLoadFile,1);
    changeXML(xmlFile,'desired_kinematics_file', strcat(path.resultsIK,trialInfo.fileName,'_IK_motion_file.mot'),1);
    changeXML(xmlFile,'task_set_file', path.RRA_tasks,1);
    changeXML(xmlFile,'constraints_file',' ',1);% empty
    changeXML(xmlFile,'adjusted_com_body','torso',1);

    % Now make copy of model, rename to RRA adjusted, and set path to scaled model to adjusted model
    copyfile(path.scaledModel, strcat(path.scaledModel(1:end-5),'_RRA.osim'));
    path.scaledModel = strcat(path.scaledModel(1:end-5),'_RRA.osim');

    changeXML(xmlFile,'output_model_file', path.scaledModel,1);
end
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Inverse Dynamics  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if tasks.ID
    %% Prepare setUpFile
    xmlFile = strcat(path.input, 'inverse_dynamics_settings.xml');
    path.OpenSimInverseDynamcis = xmlFile;

    % Create folder which will populate the ID results
    path.resultsOpenSimID = [path.results,'inverse-dynamics\'];
    if ~isfolder(path.resultsOpenSimID)
        mkdir(path.resultsOpenSimID);
    end

    % Set ik file depending if RRA was used or not
    if tasks.RR
        ik_file = strcat(path.resultsRRA,'lerner-RRA_Kinematics_q.sto');
    else
        ik_file = strcat(path.resultsIK,trialInfo.fileName,'_IK_motion_file.mot');
    end

    % Change xml nodes
    if ~isfile(xmlFile); warning('Inverse dynamics not implemented yet for this model. Check setup files! Skript paused!'); pause(); end
    changeXML(xmlFile,'results_directory',path.resultsOpenSimID,1);
    changeXML(xmlFile,'time_range',[num2str(trialInfo.startTime),' ', num2str(trialInfo.endTime)],1);
    changeXML(xmlFile,'model_file',path.scaledModel,1);
    changeXML(xmlFile,'forces_to_exclude','Muscles',1);
    changeXML(xmlFile,'external_loads_file',path.extLoadFile,1);
    changeXML(xmlFile,'coordinates_file', ik_file,1);
    changeXML(xmlFile,'lowpass_cutoff_frequency_for_coordinates','6',1);
    changeXML(xmlFile,'output_gen_force_file',strcat(trialInfo.fileName,'_inverse-dynamics.sto'),1);
    changeXML(xmlFile,'output_body_forces_file',strcat(trialInfo.fileName,'_BodyForcesAtJoints.sto'),1);
end
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Static Optimization  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if tasks.SO
    %% Prepare setUpFile
    xmlFile = strcat(path.input, 'static_optimization_settings.xml');
    path.OpenSimStaticOptimization = xmlFile;
    path.forceSetFile = [path.input,'reserve_actuators.xml'];

    % Create folder which will populate the SO results
    path.resultsOpenSimSO = [path.results,'static-optimization\'];
    if ~isfolder(path.resultsOpenSimSO)
        mkdir(path.resultsOpenSimSO);
    end

    % Adjust COM position in actuator file
    COM = getCOMbody(path.scaledModel, 'pelvis');
    changeXML(path.forceSetFile,'point',[num2str(COM(1)), ' ',num2str(COM(2)), ' ', num2str(COM(3))],3);

    % Replace header
    fid  = fopen(xmlFile,'r');
    f=fread(fid,'*char')';
    fclose(fid);
    f = replaceBetween(f,'<AnalyzeTool name=', '>', strcat('<AnalyzeTool name="', trialInfo.fileName,'">'), 'Boundaries','inclusive');
    fid  = fopen(xmlFile,'w');
    fprintf(fid,'%s',f);
    fclose(fid);

    % Change xml nodes
    if ~isfile(xmlFile); warning('Static Optimization not implemented yet for this model. Check setup files! Skript paused!'); pause(); end
    changeXML(xmlFile,'model_file',path.scaledModel,1);
    changeXML(xmlFile,'replace_force_set','false',1); % defaut = false
    changeXML(xmlFile,'force_set_files', path.forceSetFile,1); % default = path.forceSetFile
    changeXML(xmlFile,'results_directory',path.resultsOpenSimSO,1);
    changeXML(xmlFile,'output_precision','8',1);
    changeXML(xmlFile,'initial_time',num2str(trialInfo.startTime),1);
    changeXML(xmlFile,'final_time',num2str(trialInfo.endTime),1);
    %changeXML(xmlFile,'solve_for_equilibrium_for_auxiliary_states','false',1);
    changeXML(xmlFile,'start_time',num2str(trialInfo.startTime),1);
    changeXML(xmlFile,'end_time',num2str(trialInfo.endTime),1);
    changeXML(xmlFile,'use_model_force_set','true',1); % default = true
    changeXML(xmlFile,'external_loads_file',path.extLoadFile,1);
    changeXML(xmlFile,'lowpass_cutoff_frequency_for_coordinates','6',1);

    % Set ik file depending if RRA was used or not
    if tasks.RR
        ik_file = strcat(path.resultsRRA,'lerner-RRA_Kinematics_q.sto');
    else
        ik_file = strcat(path.resultsIK,trialInfo.fileName,'_IK_motion_file.mot');
    end

    changeXML(xmlFile,'coordinates_file', ik_file,1);
end
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Analyze %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Prepare setUpFile
if tasks.A
    path.OpenSimAnalyze = strcat(path.input, 'analyze_settings.xml');
    xmlFile = path.OpenSimAnalyze;

    % Create folder which will populate the JR results
    path.resultsOpenSimAnalyze = [path.results,'analyze\'];
    if ~isfolder(path.resultsOpenSimAnalyze)
        mkdir(path.resultsOpenSimAnalyze);
    end

    % Replace header
    fid  = fopen(xmlFile,'r');
    f=fread(fid,'*char')';
    fclose(fid);
    f = replaceBetween(f,'<AnalyzeTool name=', '>', strcat('<AnalyzeTool name="', trialInfo.fileName,'">'), 'Boundaries','inclusive');
    fid  = fopen(xmlFile,'w');
    fprintf(fid,'%s',f);
    fclose(fid);

    % Set force set file based on Static Optimization output
    if tasks.SO
        forceSetFile4Analyze = strcat(path.resultsOpenSimSO, trialInfo.fileName,'_StaticOptimization_force.sto');
    else
        forceSetFile4Analyze = '';
    end

    % Change xml nodes
    if ~isfile(xmlFile); warning('Analyze not implemented yet for this model. Check setup files! Skript paused!'); pause(); end
    changeXML(xmlFile,'model_file',path.scaledModel,1);
    changeXML(xmlFile,'replace_force_set','false',1); % default = false
    changeXML(xmlFile,'force_set_files', path.forceSetFile,1); % default = path.forceSetFile
    changeXML(xmlFile,'results_directory',path.resultsOpenSimAnalyze,1);
    changeXML(xmlFile,'output_precision','8',1);
    changeXML(xmlFile,'initial_time',num2str(trialInfo.startTime),1);
    changeXML(xmlFile,'final_time',num2str(trialInfo.endTime),1);
    changeXML(xmlFile,'solve_for_equilibrium_for_auxiliary_states','false',1);
    changeXML(xmlFile,'start_time',num2str(trialInfo.startTime),4);
    changeXML(xmlFile,'end_time',num2str(trialInfo.endTime),4);
    changeXML(xmlFile,'forces_file', forceSetFile4Analyze,1);
    %changeXML(xmlFile,'controls_file',strcat(path.resultsOpenSimSO,'lerner-scaled_StaticOptimization_controls.xml'),1);
    changeXML(xmlFile,'external_loads_file', path.extLoadFile,1);
    changeXML(xmlFile,'joint_names', 'All',1);
    changeXML(xmlFile,'apply_on_bodies', 'child',1); % makes no difference, only in sign.
    changeXML(xmlFile,'express_in_frame', 'child',1);

    % Set ik file depending if RRA was used or not
    if tasks.RR
        ik_file = strcat(path.resultsRRA,'lerner-RRA_Kinematics_q.sto');
    else
        ik_file = strcat(path.resultsIK,trialInfo.fileName,'_IK_motion_file.mot');
    end

    changeXML(xmlFile,'coordinates_file', ik_file,1);
    changeXML(xmlFile,'lowpass_cutoff_frequency_for_coordinates','6',1);
end
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Write *.bat file and execute it %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Copy bin and opensim folder to working directory
if ~isfolder(fullfile(path.workingDirectory,'opensim'))
    copyfile(path.opensim, fullfile(path.workingDirectory,'opensim'));
end

%% Set environment
strPaths = 'REM Let Windows know where the opensim libraries are';
p1 = 'set OPENSIM=%CD%\..\..\opensim';
p2 = 'set PATH=%BIN%;%OPENSIM%;%PATH%';

%% Run Inverse Kinematics
if tasks.IK
    str_IK = 'REM Inverse Kinematics - Open Sim';
    IK1 = (['%OPENSIM%\opensim-cmd', ' ', 'run-tool',' ', path.OpenSimInverseKinematics]);
    IK2 = (['move out.log',' ', path.results, [statesFileName, Model2Use,'-InverseKinematics_out.txt']]);
    IK3 = (['move err.log',' ', path.results, [statesFileName, Model2Use,'-InverseKinematics_err.txt']]);
else
    str_IK = '';
    IK1 = '';
    IK2 = '';
    IK3 = '';
end

%% Run Residual Reduction
if tasks.RR
    str_RRA = 'REM Residual Reduction - Open Sim';
    RRA1 = (['%OPENSIM%\opensim-cmd', ' ', 'run-tool',' ', path.OpenSimResidualReduction]);
    RRA2 = (['move out.log',' ', path.results, [statesFileName,'_',Model2Use,'-ResidualReduction_out.txt']]);
    RRA3 = (['move err.log',' ', path.results, [statesFileName,'_',Model2Use,'-ResidualReduction_err.txt']]);
else
    str_RRA = '';
    RRA1 = '';
    RRA2 = '';
    RRA3 = '';
end

%% Inverse Dynamics OpenSim
if tasks.ID
    str_ID = 'REM Inverse Dynamics - Open Sim';
    ID1 = (['%OPENSIM%\opensim-cmd', ' ', 'run-tool',' ', path.OpenSimInverseDynamcis]);
    ID2 = (['move out.log',' ', path.results, [statesFileName,'OpenSim-InverseDynamics_out.txt']]);
    ID3 = (['move err.log',' ', path.results, [statesFileName,'OpenSim-InverseDynamics_err.txt']]);
else
    str_ID = '';
    ID1 = '';
    ID2 = '';
    ID3 = '';
end

%% Static Optimization OpenSim
if tasks.SO
    str_SO = 'REM Static Optimization - Open Sim';
    SO1 = (['%OPENSIM%\opensim-cmd', ' ', 'run-tool',' ', path.OpenSimStaticOptimization]);
    SO2 = (['move out.log',' ', path.results, [statesFileName,'OpenSim-StaticOptimizations_out.txt']]);
    SO3 = (['move err.log',' ', path.results, [statesFileName,'OpenSim-StaticOptimization_err.txt']]);
else
    str_SO = '';
    SO1 = '';
    SO2 = '';
    SO3 = '';
end

%% Analyze
if tasks.A
    str_AN = 'REM ANALYZE - Open Sim';
    AN1 = (['%OPENSIM%\opensim-cmd', ' ', 'run-tool',' ', path.OpenSimAnalyze]);
    AN2 = (['move out.log',' ', path.results, [statesFileName,'OpenSim-Analyzes_out.txt']]);
    AN3 = (['move err.log',' ', path.results, [statesFileName,'OpenSim-Analyze_err.txt']]);
else
    str_AN = '';
    AN1 = '';
    AN2 = '';
    AN3 = '';
end
%% Add more here
% < .... >



%% End Bat file
line_end = 'exit'; % this makes sure that cmd windows closes when finished

% Write bat file to subject folder
batFilePart = strcat('start-',Model2Use,'Simulation__');
batFilePath = strcat(path.results,batFilePart,statesFileName,'.bat');
fid = fopen(batFilePath,'wt');
fprintf(fid, '%s\n%s\n%s\n\n%s\n%s\n%s\n%s\n\n%s\n%s\n%s\n%s\n\n%s\n%s\n%s\n%s\n\n%s\n%s\n%s\n%s\n\n%s\n%s\n%s\n%s\n\n%s', ...
    strPaths,p1, p2, ...
    str_IK, IK1, IK2, IK3, ...
    str_RRA, RRA1, RRA2, RRA3, ...
    str_ID, ID1, ID2, ID3, ...
    str_SO, SO1, SO2, SO3, ...
    str_AN, AN1, AN2, AN3, ...
    line_end);
fclose(fid);

%% Execute *.bat file in cmd
cd(path.results);

eval(strcat('!',batFilePart, statesFileName,'.bat',' &'));  % '&' give the command back to matlab and run next cmd window
pause(5); % give cmd window time to load
cd(path.workingDirectory);

% Save workspace for later
save(strcat(path.results, 'workspace.mat')); % This is used for example for the ErrorReport

%% Display finished message %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp(['>>>>> ', Model2Use,'*.xml files created for "', trialInfo.fileName,'" and passed to cmd window ...']);
end