function [InputData, node] = getFirstAndLastFrame(mot_data, mot_labels, condition, FPs, k, i, trialCnt, stepCnt, paths, events, delta, InputData, markersTrial, cam_rate)

try
    % Get the data    
    time = mot_data(:,contains(mot_labels,'time'));

    IC = time(1);
    TO = nan;
    ICi = time(end);
    cTO = nan;
    cIC = nan;

catch
    % Set nan in case an error occures during getting the events
    IC = nan;
    TO = nan;
    ICi = nan;
    cTO = nan;
    cIC = nan;
end

% Write to final results
[~,c3dname,~] = fileparts(paths.c3d{k});
node = strcat('trial',num2str(trialCnt),'_', c3dname);

% Replace forbidden chars
node = replace(node, "-", "_"); % added 28.02.2026

InputData.(node).name = char(strcat(c3dname,'_',num2str(stepCnt))); %char(c3dname);
InputData.(node).c3dPath = char(paths.c3d(k));
InputData.(node).enfPath = char(paths.enf(k));
InputData.(node).trcPath = char(paths.trc(k));
InputData.(node).motPath = char(paths.mot(k));
InputData.(node).static_trcPath = char(paths.trc_static);
InputData.(node).static_motPath = char(paths.mot_static);
InputData.(node).Side =  'fullTrial';
InputData.(node).IC = IC;
InputData.(node).TO = TO;
InputData.(node).ICi = ICi;
InputData.(node).cTO = cTO;
InputData.(node).cIC = cIC;
InputData.(node).condition = condition;
InputData.(node).fromc3d = events;

%% Clear variables except output to prevet memory leak.
clearvars -except InputData node
end