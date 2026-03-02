function [InputData, node] = getEventsPLUS(mot_data, mot_labels, condition, FPs, k, i, trialCnt, stepCnt, paths, events, delta, InputData,mkrs, mot_rate, mkrs_rate)

side = char(FPs(i)); % % changed: jh (28.01.2025)
% side = 'Left';

% Get the data
dat = mot_data(:,contains(mot_labels,strcat(num2str(i),'_vy')));
time = mot_data(:,contains(mot_labels,'time'));
threshold=50; % % jh (14.04.2025): threshold 20 N

% Decide if walking trial or SEBT trial
switch condition
    % % % Walking
    case {'Gait','Running','Cutting Left','Cutting Right'}
        fp_contact = time((dat>threshold));
        IC = fp_contact(1);
        TO = fp_contact(end);
        ICi = IC*mot_rate-1; % % jh (04.02.25): adapted for Gait

        % contralateral TO % IC contralateral      
        % % jh (04.02.25): adapted for Gait
        if isempty(FPs{1}) || isempty(FPs{2})
            cIC = IC;
            cTO = TO;
        else
            if i == 2 % % contralateral leg is on FP(i == 1)
                dat_fp_contra = mot_data(:,contains(mot_labels,strcat(num2str(1),'_vy')));
            elseif i == 1 % % contralateral leg is on FP(i == 2)
                dat_fp_contra = mot_data(:,contains(mot_labels,strcat(num2str(2),'_vy')));
            end
            fp_contact_contra= time((dat_fp_contra>threshold));
            cIC = fp_contact_contra(1);
            cTO = fp_contact_contra(end);
        end
        
        % Get events via c3d events and mot file
        % IC ipsilateral
        % [~,loc_idx] = min(abs(events.(char(strcat(side,'_Foot_Strike')))-(IC + delta)));
        % ICi = events.(char(strcat(side,'_Foot_Strike')))(loc_idx + 1);
        
        % contralateral TO % IC contralateral
        %{
        if strcmp(side,'Right')
            [~,idx_cTO] = min(abs(events.Left_Foot_Off-(IC + delta)));
            cTO = events.Left_Foot_Off(idx_cTO);
            idx_cIC = find((events.Left_Foot_Strike > IC + delta),1, 'first');
            cIC = events.Left_Foot_Strike(idx_cIC);
        end
        
        if strcmp(side,'Left')
            [~,idx_cTO] = min(abs(events.Right_Foot_Off-(IC + delta)));
            cTO = events.Right_Foot_Off(idx_cTO);
            idx_cIC = find((events.Right_Foot_Strike > IC + delta),1, 'first');
            cIC = events.Right_Foot_Strike(idx_cIC);
        end
        %}
    % % % Counter-Movement Jump: whole movement
    %{
    case 'Counter-Movement Jump' % % whole movement
        threshold_BW=mean(dat(50:250))*0.98; % % jh (23.01.25): added for CMJ
        fp_contact = time((dat<threshold_BW)); % % jh (23.01.25): added for CMJ
        IC = fp_contact(1);  % % jh (23.01.25): added for CMJ
        waistback_z = mkrs.WaistBack(:,3);  % % jh (23.01.25): added for CMJ
        [~, waistback_z_max_z] = max(waistback_z);  % % jh (23.01.25): added for CMJ
        [~, waistback_z_min_y_landing] = min(waistback_z(waistback_z_max_z:end));  % % jh (23.01.25): added for CMJ
        TO = (waistback_z_max_z+waistback_z_min_y_landing)/mkrs_rate+time(1);  % % jh (23.01.25): added for CMJ
        ICi = IC*mot_rate-1; % % jh (23.01.25): added for CMJ
        cTO = TO; % % jh (23.01.25): added for CMJ
        cIC = IC; % % jh (23.01.25): added for CMJ
    %}
    case {'Counter-Movement Jump','Counter-Movement Jump Left','Counter-Movement Jump Right',...
        'Single-Leg Jump Left','Single-Leg Jump Right'} % % only landing
        index0 = find(dat == 0, 1,"first");
        index_threshold = find(dat(index0:end) > threshold, 1,"first");
        index_threshold = index0 + index_threshold;
        fp_contact = time(index_threshold:end); 
        IC = fp_contact(1);  
        waistback_z = mkrs.WaistBack(:,3);  
        [~, waistback_z_max_z] = max(waistback_z);  
        [~, waistback_z_min_y_landing] = min(waistback_z(waistback_z_max_z:end));  
        TO = (waistback_z_max_z+waistback_z_min_y_landing)/mkrs_rate+time(1); 
        ICi = IC*mot_rate-1; 
        cTO = TO; 
        cIC = IC; 
    case 'Drop Jump Bilateral' % % only landing
        index0 = find(dat == 0, 1,"first");
        indexJump_threshold = find(dat(index0:end) > threshold, 1,"first");
        indexJump_threshold = index0 + indexJump_threshold;
        indexJumpEnd_threshold = find(dat(indexJump_threshold:end) < threshold, 1,"first");
        indexJumpEnd_threshold = indexJump_threshold + indexJumpEnd_threshold;
        index_threshold = find(dat(indexJumpEnd_threshold:end) > threshold, 1,"first");
        index_threshold = indexJumpEnd_threshold + index_threshold;
        fp_contact = time(index_threshold:end); 
        IC = fp_contact(1);   
        waistback_z = mkrs.WaistBack(:,3);  
        [~, waistback_z_max_z] = max(waistback_z);  
        [~, waistback_z_min_y_landing] = min(waistback_z(waistback_z_max_z:end));  
        TO = (waistback_z_max_z+waistback_z_min_y_landing)/mkrs_rate+time(1); 
        ICi = IC*mot_rate-1; 
        cTO = TO; 
        cIC = IC;
    case 'Squatting' % % jh (15.04.2025): added, only landing
        waistback_z = mkrs.WaistBack(:,3);  
        threshold=mean(waistback_z(25:150))*0.99;
        index1 = (find(waistback_z < threshold, 1,"first")-1)*(mot_rate/mkrs_rate);
        index2 = (find(waistback_z < threshold, 1,"last")-1)*(mot_rate/mkrs_rate);
        IC = time(index1);
        TO = time(index2);
        ICi = IC*mot_rate-1; 
        cTO = TO; 
        cIC = IC;
    case 'Squatting Left' % % jh (15.04.2025): added, only landing
        waistback_z = mkrs.WaistBack(:,3);  
        threshold=mean(waistback_z(25:150))*0.99;
        index1 = (find(waistback_z < threshold, 1,"first")-1)*(mot_rate/mkrs_rate);
        index2 = (find(waistback_z < threshold, 1,"last")-1)*(mot_rate/mkrs_rate);
        IC = time(index1);
        TO = time(index2);
        ICi = IC*mot_rate-1; 
        cTO = TO; 
        cIC = IC; 
    case 'Squatting Right' % % jh (15.04.2025): added, only landing
        waistback_z = mkrs.WaistBack(:,3);  
        threshold=mean(waistback_z(25:150))*0.99;
        index1 = (find(waistback_z < threshold, 1,"first")-1)*(mot_rate/mkrs_rate);
        index2 = (find(waistback_z < threshold, 1,"last")-1)*(mot_rate/mkrs_rate);
        IC = time(index1);
        TO = time(index2);
        ICi = IC*mot_rate-1; 
        cTO = TO; 
        cIC = IC;
    case 'Generic' % % % jh (14.05.2025): added for Y-Balance-Test (Gerlinde Greiner)
        % if 
        waistback_z = mkrs.WaistBack(:,3);  
        threshold=mean(waistback_z(25:150))*0.99;
        index1 = (find(waistback_z < threshold, 1,"first"))*(mot_rate/mkrs_rate);
        index2 = (find(waistback_z < threshold, 1,"last"))*(mot_rate/mkrs_rate);
        IC = time(index1);
        TO = time(index2);
        ICi = IC*mot_rate-1; 
        cTO = TO; 
        cIC = IC;
end

% Write to final results
[~,c3dname,~] = fileparts(paths.c3d{k});
side_out = char(lower(side(1)));
% node = (strcat('trial',num2str(trialCnt),'_', c3dname,'_',num2str(stepCnt),'_', side_out));
switch condition
    case {'Gait','Generic','Running'}
        c3dname = strrep(c3dname,[condition,' '],[condition,'_']);
    case {'Cutting Left'}
        c3dname = strrep(c3dname,[condition,' '],'cutting_le_');
    case {'Cutting Right'}
        c3dname = strrep(c3dname,[condition,' '],'cutting_ri_');
    case 'Counter-Movement Jump'
        c3dname = strrep(c3dname,[condition,' '],'cmj_');
    case 'Counter-Movement Jump Left'
        c3dname = strrep(c3dname,[condition,' '],'cmj_le_');
    case 'Counter-Movement Jump Right'
        c3dname = strrep(c3dname,[condition,' '],'cmj_ri_');
    case 'Drop Jump Bilateral'
        c3dname = strrep(c3dname,[condition,' '],'dj_');
    case 'Single-Leg Jump Left'
        c3dname = strrep(c3dname,[condition,' '],'slj_le_');
    case 'Single-Leg Jump Right'
        c3dname = strrep(c3dname,[condition,' '],'slj_ri_');
    case 'Squatting'
        c3dname = strrep(c3dname,[condition,' '],'squat_');
    case 'Squatting Left'
        c3dname = strrep(c3dname,[condition,' '],'squat_le_');
    case 'Squatting Right'
        c3dname = strrep(c3dname,[condition,' '],'squat_ri_');
end
node = (strcat(c3dname,'_',side_out)); % % jh (05.02.25): changed

InputData.(node).name = char(c3dname); % char(strcat(c3dname,'_',num2str(stepCnt))); % jh (28.01.)
InputData.(node).c3dPath = char(paths.c3d(k));
InputData.(node).enfPath = char(paths.enf(k));
InputData.(node).trcPath = char(paths.trc(k));
InputData.(node).motPath = char(paths.mot(k));
InputData.(node).static_trcPath = char(paths.trc_static);
InputData.(node).static_motPath = char(paths.mot_static);
InputData.(node).Side =  lower(char(side));
InputData.(node).IC = IC;
InputData.(node).TO = TO; 
InputData.(node).ICi = ICi-delta; % Vicon start frame delta to mot
InputData.(node).cTO = cTO-delta; % Vicon start frame delta to mot
InputData.(node).cIC = cIC-delta; % Vicon start frame delta to mot
InputData.(node).condition = condition;
InputData.(node).fromc3d = events;

%% Clear variables except output to prevet memory leak.
clearvars -except InputData node
end
