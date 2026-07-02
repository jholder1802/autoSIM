function [folderPaths, folderNames] = getAllFoldersToAnalyze(folderPath, prefix, condition)
% This file gets all folder names and paths that contain the substrings
% "prefix" and "condition". If prefix is empty it only uses conditions.

% Written by: Brian Horsak
% Last edited: 18.07.2023
% -------------------------------------------------------------------------
% Use the dir function to get a list of files and folders in the specified folder
dirData = dir(folderPath);

% Filter out only the folders
folders = dirData([dirData.isdir]);

% Exclude '.' and '..' directories from the list
folders = folders(~ismember({folders.name}, {'.', '..'}));

% Initialize an empty array to store the matching cell indices
folderNames = [];
folderPaths = [];

% % % added to shorten filename: jh (10.11.2025)
if contains(condition,'Counter-Movement Jump')
    condition = 'cmj';
elseif contains(condition,'Counter-Movement Jump Left')
    condition = 'cmj_le';
elseif contains(condition,'Counter-Movement Jump Right')
    condition = 'cmj_ri';
elseif contains(condition,'Drop Jump Bilateral')
    condition = 'dj';
elseif contains(condition,'Gait')
    condition = 'Gait';
elseif contains(condition,'Single-Leg Jump Left')
    condition = 'slj_le';
elseif contains(condition,'Single-Leg Jump Right')
    condition = 'slj_ri';
elseif contains(condition,'Squatting')
    condition = 'squat';
elseif contains(condition,'Squatting Left')
    condition = 'squat_le';
elseif contains(condition,'Squatting Right')
    condition = 'squat_ri';
end

if strcmp(prefix, '') % if prefix is empty
    % Extract the folder paths
    folders = folders(contains({folders.name}, {condition}));
    folderPaths = fullfile(folderPath, {folders.name})';
    folderNames =  {folders.name}';
else
    % Check if both substrings are present in the current string
    cellArray = {folders.name};
    cnt = 1;
    for i = 1:numel(cellArray)
        folderName = cellArray{i};

        if contains(folderName, prefix) && contains(folderName, condition)
            % Extract the folder paths
            folderPaths{cnt,1} = strcat(folderPath, folderName);
            folderNames{cnt,1} = folderName;
            cnt = cnt +1;
        end
    end
end

%% Clear variables except output to prevet memory leak.
clearvars -except folderPaths folderNames
end

