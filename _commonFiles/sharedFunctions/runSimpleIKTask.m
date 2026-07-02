function [resultsAreValid, IK_results_OutputPath] = runSimpleIKTask(setupFile, modelFile, sampleInput, outputPath, path2JamPlugIn)
% This function runs a quick IK tasks to have IK results that are needed to check the muscle moment arms.

% Written by: Willi Koller
% Downloaded and modified by B. Horsak (12.03.2024) from
% https://github.com/WilliKoller/OpenSimMatlabBasic
% -------------------------------------------------------------------------


% Load opensim API and comak-plugin.
import org.opensim.modeling.*
if ~isempty(path2JamPlugIn)
    opensimCommon.LoadOpenSimLibrary(path2JamPlugIn);
end

% Set paths.
IK_results_OutputPath = fullfile(outputPath, 'tmp_IKresults2checkMomArms.mot');

% Create folder if it does not exist.
if ~exist(outputPath, 'dir')
    mkdir(outputPath)
end

% Start IK Tool
ikTool = InverseKinematicsTool(setupFile);
osimModel = Model(modelFile);

ikTool.setModel(osimModel);
ikTool.setMarkerDataFileName(sampleInput.trcPath);
ikTool.setStartTime(sampleInput.IC);
ikTool.setEndTime(sampleInput.ICi);
ikTool.setOutputMotionFileName(IK_results_OutputPath);
ikTool.setResultsDir(outputPath)
%ikTool.print(fullfile(outputPath, 'ikSettings.xml'));
ikTool.run();

copyfile('_ik_marker_errors.sto', fullfile(outputPath, 'tmp_IKmarkerErrors2checkMomArms.sto'));
delete('_ik_marker_errors.sto');

% Check for quality of IK solution.
errors = load_sto_file(fullfile(outputPath, 'tmp_IKmarkerErrors2checkMomArms.sto'));
delete(fullfile(outputPath, 'tmp_IKmarkerErrors2checkMomArms.sto'));

[maxMarkerError, ~] = max(errors.marker_error_max);
[maxRMSError, ~] = max(errors.marker_error_RMS);

if maxRMSError <= 0.1 % % 0.03 (2025/04/04) angepasst (jh)
    resultsAreValid = true;
else
    resultsAreValid = false;
end

%% Clear variables except output to prevet memory leak.
clearvars -except resultsAreValid IK_results_OutputPath
end