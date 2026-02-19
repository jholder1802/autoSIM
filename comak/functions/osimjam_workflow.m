function osimjam_workflow(workingDirectory, path2bin, path2opensim, path2setupFiles,  side, filename, path2trc, path2mot, path2extLoad, path2scaledModel, IC, cTO, cIC, TO, ICi, ContactEenergy, MuscleWeight, BW, prefix, tf_angle_r, tf_angle_l, timeNorm, secondary_constraint_function_file, second_constraints, secondary_coupled_coordinate, labFlag, writeVtp, jamSettings)
% -------------------------------------------------------------------------
% This function will run the OpenSim-JAM including COMAK in Matlab. Several
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
% ContactEnergy: value of Contact Energy weighting, e.g. 500
% MuscleWeight: 'true' or 'false'. Weights are predefined in setting files
% BW: body weight, e.g. 95 kg * 9.81 m/s^2
% prefix: string, prefix used for naming, e.g. 'test_'; leave blank if not
% used
% tf_angle_l / tf_angle_l: angle in degrees used to change frontal knee
% alignment in start script.
% timeNorm: defines if data should be 100% gait normalized
% labFlag: string specifiying which lab the data come from
% ...
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
% Ref. for OpenSim-JAM and COMAK: https://github.com/clnsmith/opensim-jam
%
%
% Written by:           Brian Horsak - brian.horsak@fhstp.ac.at
% Acknowledgements:     Many thx to Bryce Killian (KU Leuven) for his great
%                       support
%
% Last changed:         10/2023
% -------------------------------------------------------------------------

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  USER SETTINGS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Visualize tasks during processing
vis_secCon = 'true';
vis_comak = 'false'; % shows visualizer for each cmd window, not recommended!

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Some housekeeping variables %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Specify if contact energy should be weighted
% Default from walking example: 500
contactEnergy = ContactEenergy;

% Specify if muscle should be weighted. Note: Muscle weights need to be set directly in the "2_comak_settings_xxxx_muscleWeights.xml" files
% Default from walking example: 'true' and contact energy: 0
muscleWeight = MuscleWeight; %'true';

% Create lab specific paths
% NOTE: to add a new lab you will only need to add it to the switch
% statement. No furtehr changes to the code should be necessary here.

switch labFlag

    case 'ISW'
        path2setupFiles = fullfile(path2setupFiles,'Models\ISW\');

    case {'OSS', 'FHSTP-BIZ', 'FHSTP'}
        path2setupFiles = fullfile(path2setupFiles,'Models\OSS_FHSTP\');

    case {'OSSnoArms', 'FHSTPnoArms'}
        path2setupFiles = fullfile(path2setupFiles,'Models\OSS_FHSTPnoArms\');

    case {'LKHG_Cleve'}
        path2setupFiles = fullfile(path2setupFiles,'Models\LKHG_Cleve\');

    case {'LKHG_PiG'}
        path2setupFiles = fullfile(path2setupFiles,'Models\LKHG_PiG\');
    
    case 'PLUS_COD_noArms'
        path2setupFiles = fullfile(path2setupFiles,'Models\PLUS_COD_noArms\');

    case {'PLUS_SportsMarkerset_noArms','PLUS_SportsMarkerset_noArms_newFPs'}
        path2setupFiles = fullfile(path2setupFiles,'Models\_PLUS_pilotMC_noArms\');

end

% Set some necessary paths
% Paths to this repository (setup files and opensim executable)
path.bin = path2bin;
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
trialInfo.endTime = TO;  % default: % ICi; % Huthöfer
trialInfo.fileName = strcat(prefix, filename, '_', lower(side(1)));

%% Create COMAK input and results folder and Copy setupFiles in working directory
% Add folders to path
path.COMAKresults = strcat(path.workingDirectory,'JAM\',trialInfo.fileName,'\');
path.COMAKinput = strcat(path.COMAKresults, '_input\');

% Now copy files to the new input folder
copyfile(strcat(path.setupFiles,'ComakSetUpFiles\'), path.COMAKinput);
% Note: Geomtry folder was already copied to the working directory during scaling

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% COMAK - Inverse Kinematics %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Prepare setUpFile
xmlFile = strcat(path.COMAKinput, '1_comak_inverse_kinematics_settings.xml');

% Create folder and set path to inverse-kinematics subfolder
path.COMAKresultsIK = [path.COMAKresults,'inverse-kinematics\'];
if ~isfolder(path.COMAKresultsIK)
mkdir(path.COMAKresultsIK);
end

% Change xml nodes
changeXML(xmlFile,'model_file',path.scaledModel,1); % the second model file in IK stays as unassigned
changeXML(xmlFile,'results_directory',path.COMAKresultsIK,2); % Note: this changes two nodes at once because they are named identically
changeXML(xmlFile,'results_prefix',trialInfo.fileName,1);
changeXML(xmlFile,'perform_secondary_constraint_sim','false',1) % I did this already in run_secConstrainSimulation
changeXML(xmlFile,'secondary_coupled_coordinate',secondary_coupled_coordinate,1);
changeXML(xmlFile,'secondary_coordinates',second_constraints,1);
changeXML(xmlFile,'secondary_coupled_coordinate_stop_value','120',1);
changeXML(xmlFile,'perform_inverse_kinematics','true',1); % Default 'true'
changeXML(xmlFile,'secondary_constraint_function_file',secondary_constraint_function_file,1);
changeXML(xmlFile,'marker_file',path.trc,1);
changeXML(xmlFile,'constraint_weight','Inf',1); % default = 'Inf' 
changeXML(xmlFile,'time_range',[num2str(trialInfo.startTime),' ', num2str(trialInfo.endTime)],1);

path.COMAK_PrescPrimSecond_cood_IK_resultsFile = strcat(path.COMAKresultsIK,trialInfo.fileName,'_IK_motion_file.mot');
changeXML(xmlFile,'output_motion_file',path.COMAK_PrescPrimSecond_cood_IK_resultsFile,1);
changeXML(xmlFile,'use_visualizer',vis_secCon,1);
changeXML(xmlFile,'verbose','2',1); % 0: low, 1: medium, 2: high

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% COMAK Tool %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Prepare setupFile depending on initial settings to contact energy and muscles weights
if strcmp(side,'right') && strcmp(muscleWeight,'false')
    xmlFile = strcat(path.COMAKinput, '2_comak_settings_right.xml');
    path.currentCOMAKsetting = xmlFile;
elseif strcmp(side,'right') && strcmp(muscleWeight,'true')
    xmlFile = strcat(path.COMAKinput, '2_comak_settings_right_muscleWeight.xml');
    path.currentCOMAKsetting = xmlFile;
elseif strcmp(side,'left') && strcmp(muscleWeight,'false')
    xmlFile = strcat(path.COMAKinput, '2_comak_settings_left.xml');
    path.currentCOMAKsetting = xmlFile;
elseif strcmp(side,'left') && strcmp(muscleWeight,'true')
    xmlFile = strcat(path.COMAKinput, '2_comak_settings_left_muscleWeight.xml');
    path.currentCOMAKsetting = xmlFile;
end

% Change xml nodes
changeXML(xmlFile,'model_file',path.scaledModel,1);
changeXML(xmlFile,'coordinates_file', path.COMAK_PrescPrimSecond_cood_IK_resultsFile,1);
changeXML(xmlFile,'external_loads_file',path.extLoadFile,1);

% Set force file
switch side
    case 'right'
        path.forceSetFile = [path.COMAKinput,'reserve_actuators_right.xml'];
    case 'left'
        path.forceSetFile = [path.COMAKinput,'reserve_actuators_left.xml'];
end
changeXML(xmlFile,'force_set_file',path.forceSetFile,1);
changeXML(xmlFile,'start_time',num2str(trialInfo.startTime),1);
changeXML(xmlFile,'stop_time',num2str(trialInfo.endTime),1);
changeXML(xmlFile,'time_step','0.01',1); % Default 0.01
changeXML(xmlFile,'lowpass_filter_frequency','10',1); % default 6, Markus has tested 10 Hz for kinematics and kinetics and it looks good so far

% Contact energy settings 
changeXML(xmlFile,'contact_energy_weight',num2str(contactEnergy),1);

simResultsName = strcat(trialInfo.fileName,'_comak_settle_sim_results');
changeXML(xmlFile,'settle_sim_results_prefix',simResultsName,1);
statesFileName = strcat(trialInfo.fileName,'_');
changeXML(xmlFile,'results_prefix',statesFileName,1); % Add info about contact energy to all results files

% Create folder which will populate the simple comak results
path.COMAKresultsTool = [path.COMAKresults,'comak\'];
if ~isfolder(path.COMAKresultsTool)
mkdir(path.COMAKresultsTool);
end

% Create folder and set path to jam subfolder for simple comak results
path.COMAKresultsJAM = [path.COMAKresults,'jam\'];
if ~isfolder(path.COMAKresultsJAM)
mkdir(path.COMAKresultsJAM);
end

changeXML(xmlFile,'results_directory', path.COMAKresultsTool,1);
changeXML(xmlFile,'settle_sim_results_directory',path.COMAKresultsTool,1);
changeXML(xmlFile,'verbose','2',1); % 0: low, 1: medium, 2: high
changeXML(xmlFile,'use_visualizer',vis_comak,1);

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Joint Mechanics Analysis %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
xmlFile = strcat(path.COMAKinput, '3_joint_mechanics_settings.xml');
path.jointMechanicsAnalysis = xmlFile;

% Change xml nodes
changeXML(xmlFile,'model_file',path.scaledModel,1);
changeXML(xmlFile,'states_file',strcat(path.COMAKresultsTool,statesFileName, '_states.sto'),1);
changeXML(xmlFile,'results_directory', path.COMAKresultsJAM,1);
changeXML(xmlFile,'results_file_basename', statesFileName,1);
changeXML(xmlFile,'start_time',num2str(trialInfo.startTime),1); % trialInfo.startTime
changeXML(xmlFile,'stop_time',num2str(trialInfo.endTime),1);
changeXML(xmlFile,'normalize_to_cycle', timeNorm,1); % Will normalize to 100% gait cycle
changeXML(xmlFile,'lowpass_filter_frequency','10',1); % Default = -1 (false) % default 6, Markus has tested 10 Hz for kinematics and kinetics and it looks good so far
changeXML(xmlFile,'print_processed_kinematics','true',1); % Default = false
changeXML(xmlFile,'write_vtp_files',char(string(writeVtp)),1); % Default = true
changeXML(xmlFile,'write_h5_file','true',1);

changeXML(xmlFile,'contacts','all',1);
changeXML(xmlFile,'contact_outputs','all',1);
changeXML(xmlFile,'contact_mesh_properties','all',1);
changeXML(xmlFile,'ligaments', jamSettings.ligaments,1);
changeXML(xmlFile,'ligament_outputs','all',1);
changeXML(xmlFile,'muscles','none',1);
changeXML(xmlFile,'muscle_outputs','none',1);
% Add bodyside to the body paths
attachedGeometryBodies = strrep(jamSettings.attachedGeometryBodies, '#', side(1));
changeXML(xmlFile,'attached_geometry_bodies', attachedGeometryBodies,1);

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Inverse Dynamics %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Prepare setUpFile
xmlFile = strcat(path.COMAKinput, '4_inverse_dynamics_settings.xml');
path.OpenSimInverseDynamcis = xmlFile;

% Create folder which will populate the ContactEnergy weighted comak results
path.COMAKresultsOpenSimID = [path.COMAKresults,'inverse-dynamics\'];
if ~isfolder(path.COMAKresultsOpenSimID)
mkdir(path.COMAKresultsOpenSimID);
end

% Create a model without the force set and run ID with that model
path.scaledModel4IDonly = removeForceSet4IDmodel(path2scaledModel, path2bin, side);

% Change xml nodes
changeXML(xmlFile,'results_directory',path.COMAKresultsOpenSimID,1);
changeXML(xmlFile,'time_range',[num2str(trialInfo.startTime),' ', num2str(trialInfo.endTime)],1);
changeXML(xmlFile,'model_file',path.scaledModel4IDonly,1);
changeXML(xmlFile,'forces_to_exclude','Muscles',1);
changeXML(xmlFile,'external_loads_file',path.extLoadFile,1);
changeXML(xmlFile,'coordinates_file',strcat(path.COMAKresultsTool,statesFileName,'_values.sto'),1);
changeXML(xmlFile,'lowpass_cutoff_frequency_for_coordinates','6',1);
changeXML(xmlFile,'output_gen_force_file',strcat(trialInfo.fileName,'_inverse-dynamics.sto'),1);

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Analyze %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Prepare setUpFile
xmlFile = strcat(path.COMAKinput, '5_analyze_settings.xml');
path.OpenSimAnalyze = xmlFile;

% Create folder which will populate the Janalyze results
path.resultsOpenSimAnalyze = [path.COMAKresults,'analyze\'];
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

% Change xml nodes
changeXML(xmlFile,'model_file',path.scaledModel,1);
changeXML(xmlFile,'replace_force_set','false',1);
changeXML(xmlFile,'force_set_files',path.forceSetFile,1);
changeXML(xmlFile,'results_directory',path.resultsOpenSimAnalyze,1);
changeXML(xmlFile,'output_precision','8',1);
changeXML(xmlFile,'initial_time',num2str(trialInfo.startTime),1);
changeXML(xmlFile,'final_time',num2str(trialInfo.endTime),1);
changeXML(xmlFile,'solve_for_equilibrium_for_auxiliary_states','false',1);
changeXML(xmlFile,'start_time',num2str(trialInfo.startTime),4);
changeXML(xmlFile,'end_time',num2str(trialInfo.endTime),4);
changeXML(xmlFile,'forces_file',strcat(path.COMAKresultsTool,statesFileName,'_force.sto'),1);
changeXML(xmlFile,'external_loads_file',path.extLoadFile,1);
changeXML(xmlFile,'coordinates_file',strcat(path.COMAKresultsIK,trialInfo.fileName,'_IK_motion_file.mot'),1);
changeXML(xmlFile,'lowpass_cutoff_frequency_for_coordinates','6',1);

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Write *.bat file and execute it %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Run COMAK - Inverse Kinematics
% Copy bin and opensim folder to working directory
if ~isfolder(fullfile(path.workingDirectory,'bin'))
copyfile(path.bin, fullfile(path.workingDirectory,'bin')); 
end
if ~isfolder(fullfile(path.workingDirectory,'opensim'))
copyfile(path.opensim, fullfile(path.workingDirectory,'opensim'));
end

% Set environment
strPaths = 'REM Let Windows know where the plugin and opensim libraries are';
line1 = 'set BIN=%CD%\..\..\bin';
line2 = 'set OPENSIM=%CD%\..\..\opensim';
line3 = 'set PATH=%BIN%;%OPENSIM%;%PATH%';

% Run system command similar to the batch file
strCOMAK_IK = 'REM COMAK - Inverse Kinematics';
line4 = (['%BIN%\comak-inverse-kinematics',' ', '%BIN%\jam_plugin.dll', ' ', path.COMAKinput,'1_comak_inverse_kinematics_settings.xml']); %'1_comak_inverse_kinematics_settings_fully_body.xml' 1_comak_inverse_kinematics_settings.xml
line5 = (['move out.log',' ', path.COMAKresults, [trialInfo.fileName,'_comak-IK_out.txt']]);
line6 = (['move err.log',' ', path.COMAKresults, [trialInfo.fileName,'_comak-IK_err.txt']]);

%% Run COMAK - Tool
% Run system command similar to the batch file
strCOMAK = 'REM Run COMAK - Tool';
line7 = (['%BIN%\comak',' ', '%BIN%\jam_plugin.dll',' ', path.currentCOMAKsetting]);
line8 = (['move out.log',' ', path.COMAKresults, [statesFileName,'_comak-Tool_out.txt']]);
line9 = (['move err.log',' ', path.COMAKresults, [statesFileName,'_comak-Tool_err.txt']]);

%% Run Joint Mechanics Analysis
% Run system command similar to the batch file
strJAM = 'REM Run Joint Mechanics Analysis';
line10 = (['%BIN%\joint-mechanics',' ', '%BIN%\jam_plugin.dll',' ', path.jointMechanicsAnalysis]);
line11 = (['move out.log',' ', path.COMAKresults, [statesFileName,'_JAM_out.txt',]]);
line12 = (['move err.log',' ', path.COMAKresults, [statesFileName,'_JAM_err.txt',]]);

%% Inverse Dynamics OpenSim
strID = 'REM Inverse Dynamics - Open Sim';
line13 = (['%OPENSIM%\opensim-cmd -L',' ', '%BIN%\jam_plugin.dll run-tool',' ', path.OpenSimInverseDynamcis]);
line14 = (['move out.log',' ', path.COMAKresults, [statesFileName,'_OpenSim-Inverse-Dynamics_out.txt']]);
line15 = (['move err.log',' ', path.COMAKresults, [statesFileName,'_OpenSim-Inverse-Dynamics_err.txt']]);

%% Analyze
str_AN = 'REM ANALYZE - Open Sim';
AN1 = (['%OPENSIM%\opensim-cmd -L',' ', '%BIN%\jam_plugin.dll run-tool',' ', path.OpenSimAnalyze]);
AN2 = (['move out.log',' ', path.COMAKresults, [statesFileName,'OpenSim-Analyzes_out.txt']]);
AN3 = (['move err.log',' ', path.COMAKresults, [statesFileName,'OpenSim-Analyze_err.txt']]);

%% End Bat file
line_end = 'exit'; % this makes sure that cmd windows close when finished

% Write bat file to subject folder
batFilePart = 'start-comakJAM__';
batFilePath = strcat(path.COMAKresults,batFilePart,statesFileName,'.bat');
fid = fopen(batFilePath,'wt');
fprintf(fid, '%s\n%s\n%s\n%s\n\n%s\n%s\n%s\n%s\n\n%s\n%s\n%s\n%s\n\n%s\n%s\n%s\n%s\n\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s', ...
              strPaths,line1, line2, line3, ...
              strCOMAK_IK, line4, line5, line6, ...
              strCOMAK, line7, line8, line9, ...
              strJAM, line10, line11, line12, ...
              strID, line13, line14, line15, ...
              str_AN, AN1, AN2, AN3, ...
              line_end);
fclose(fid);

%% Execute *.bat file in cmd
cd(path.COMAKresults);

eval(strcat('!',batFilePart, statesFileName,'.bat',' &'));  % '&' give the command back to matlab and run next cmd window
pause(5); % give cmd window time to load
cd(path.workingDirectory);

% Save workspace for later
save(strcat(path.COMAKresults, 'workspace.mat')); % This is used for example for the ErrorReport

%% Display finished message %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp(['>>>>> COMAK *.xml files created for "', trialInfo.fileName,'" and passed to cmd window ...']);


%% Clear variables except output to prevet memory leak.
clearvars
end