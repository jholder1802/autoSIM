function [TRC_out, GRF_out] = c3d2OpenSim(c3dfile, labFlag, markerSet, pelvisMarker)
%% C3D to OpenSim
%------------------
% Maarten Afschrift, OpenSim Workshop Leuven, 2018
% Modified by: Mark Simonlehner 02.03.2020
% Modified by: Brian Horsak 02/2025:

% This file is used to transform c3d data to *.mot and *.trc files for OpenSim.


%% Path information
c3dfile_name = c3dfile(1:strfind(c3dfile,'.')-1);
TRC_out= strcat(c3dfile_name,'.trc');
GRF_out= strcat(c3dfile_name,'.mot');

%% Standard rotation matrices for force plates and markers
% NOTE: to add a new lab you will only need to add it to the switch
% statement. No furtehr changes to the code should be necessary here.

switch labFlag
    case 'FHSTP-BIZ' % has only one plate
        % Rotation matrix from c3d to OpenSim for Markers
        R1 = rotx(0.5*pi);  % rotate 90 degrees around X
        R3 = rotz(pi);      % rotate 180 degrees around z
        R1 = R1(1:3,1:3);   % remove translation
        R3 = R3(1:3,1:3);   % remove translation
        R =  R3*R1;         % Total rotation

        % Rotation matrix force plate to coordinate system used in c3d file
        R_FPa = roty(1*pi);     % rotate 180 degrees y
        R_FPb =  rotz(0.5*pi);  % rotate 180 degrees z
        R_FPa = R_FPa(1:3,1:3); % remove translation
        R_FPb = R_FPb(1:3,1:3); % remove translation
        R_FP = R_FPa*R_FPb;     % Total rotation

        % Rotate all force plates
        RotMat = rotz(pi); % 180 degrees rot matrix
        R_FP1 = R_FP*RotMat(1:3,1:3); % turn

    case {'FHSTP', 'FHSTPnoArms', 'FHSTP-pyCGM', 'FHSTP_pyCGM2_5', 'FHSTP_pyCGM2_5noArms'} % has three plates
        % Rotation matrix from c3d to OpenSim for Markers
        R1 = rotx(0.5*pi);  % rotate 90 degrees around X
        R2 = roty(pi);      % rotate 180  around y
        R3 = rotz(pi);      % rotate 180 degrees around z
        R1 = R1(1:3,1:3);   % remove translation
        R2 = R2(1:3,1:3);   % remove translation
        R3 = R3(1:3,1:3);   % remove translation
        R = R3*R2*R1;       % Total rotation

        % Rotation matrix force plate to coordinate system used in c3d file
        R_FPa = roty(pi);       % rotate 180 degrees y
        R_FPb =  rotz(0.5*pi);  % rotate 180 degrees z
        R_FPa = R_FPa(1:3,1:3); % remove translation
        R_FPb = R_FPb(1:3,1:3); % remove translation
        R_FP = R_FPa*R_FPb;     % Total rotation

        % Rotate all force plates
        RotMat = rotz(pi);              % 180 degrees rot matrix
        R_FP1 = R_FP*RotMat(1:3,1:3);   % turn
        R_FP2 = R_FP*RotMat(1:3,1:3);   % turn
        R_FP3 = R_FP*RotMat(1:3,1:3);   % turn

    case {'OSS', 'OSSnoArms', 'OSS-pyCGM'} % has three to seven plates
        % Rotation matrix from c3d to OpenSim for Markers
        R1 = rotx(0.5*pi);  % rotate 90 degrees around x
        R2 = roty(pi);      % rotate 180  around y
        R3 = rotz(pi);      % rotate 180 degrees around z
        R1 = R1(1:3,1:3);   % remove translation
        R2 = R2(1:3,1:3);   % remove translation
        R3 = R3(1:3,1:3);   % remove translation
        R = R3*R2*R1;       % Total rotation

        % Rotation matrix force plate to coordinate system used in c3d file
        R_FPa = roty(pi);       % rotate 180 degrees y
        R_FPb = rotz(0.5*pi);   % rotate 90 degrees z
        R_FPa = R_FPa(1:3,1:3); % remove translation
        R_FPb = R_FPb(1:3,1:3); % remove translation
        R_FP = R_FPa*R_FPb;    % Total rotation

        % Rotate all force plates
        RotMat = rotz(pi);  % turn 180 degrees
        R_FP1 = R_FP; %
        R_FP2 = R_FP*RotMat(1:3,1:3);   % turn
        R_FP3 = R_FP*RotMat(1:3,1:3);   % turn
        R_FP4 = R_FP*RotMat(1:3,1:3);   % turn
        R_FP5 = R_FP*RotMat(1:3,1:3);   % turn
        R_FP6 = R_FP; %
        R_FP7 = R_FP; %

    case {'FHCWnoArms', 'FHCW'} % has nine plates
        % Rotation matrix from c3d to OpenSim for Markers
        R1 = rotx(0.5*pi);  % rotate 90 degrees around x
        R2 = roty(pi);      % rotate 180 degrees around y
        R3 = rotz(pi);      % rotate 180 degrees around z
        R1 = R1(1:3,1:3);   % remove translation
        R2 = R2(1:3,1:3);   % remove translation
        R3 = R3(1:3,1:3);   % remove translation
        R = R3*R2*R1;       % Total rotation

        % Rotation matrix force plate to coordinate system used in c3d file
        % level and ramp walking
        R_FPa = roty(pi);       % rotate 180degrees y
        R_FPa = R_FPa(1:3,1:3); % remove translation
        R_FPs56789 =  R_FPa;
        % stairs
        R_FPa = roty(pi);       % rotate 180degrees y
        R_FPb = rotz(0.5*pi);   % rotate 90degrees z
        R_FPa = R_FPa(1:3,1:3); % remove translation
        R_FPb = R_FPb(1:3,1:3); % remove translation
        R_FPs1234 = R_FPa*R_FPb;% Total rotation

        % Rotate all force plates
        R_FP1 = R_FPs1234;  % turn check
        R_FP2 = R_FPs1234;  % turn check
        R_FP3 = R_FPs1234;  % turn check
        R_FP4 = R_FPs1234;  % turn check

        RotMatz = rotz(pi); % 180degrees rot matrix
        R_FP5 = R_FPs56789*RotMatz(1:3,1:3);  % turn check
        R_FP6 = R_FPs56789*RotMatz(1:3,1:3);  % turn check
        R_FP7 = R_FPs56789*RotMatz(1:3,1:3);  % turn ok
        R_FP8 = R_FPs56789*RotMatz(1:3,1:3);  % turn ok
        R_FP9 = R_FPs56789*RotMatz(1:3,1:3);  % turn ok

    case 'ISW' % has five plates
        % Rotation matrix from c3d to OpenSim for Markers
        R1 = rotx(0.5*pi);  % rotate 90degrees around X
        R3 = rotz(pi);      % rotate 180degrees around z
        R1 = R1(1:3,1:3);   % remove translation
        R3 = R3(1:3,1:3);   % remove translation
        R = R3*R1;          % Total rotation

        % Rotation matrix force plate to coordinate system used in c3d file
        R_FPa = roty(pi);       % rotate 180degrees y
        R_FPa = R_FPa(1:3,1:3); % remove translation
        R_FP =  R_FPa;

        % Rotate all force plates
        RotMatz = rotz(pi);             % 180degrees rot matrix
        R_FP1 = R_FP*RotMatz(1:3,1:3);  % turn
        R_FP2 = R_FP*RotMatz(1:3,1:3);  % turn
        R_FP3 = R_FP*RotMatz(1:3,1:3);  % turn
        R_FP4 = R_FP*RotMatz(1:3,1:3);  % turn
        R_FP5 = R_FP*RotMatz(1:3,1:3);  % turn

    case 'FF'
        % Rotation matrix from c3d to OpenSim for Markers
        R1 = rotx(0.5*pi); %rotate 90degrees around X
        R3 = rotz(pi); %rotate 180degrees around z
        R1 = R1(1:3,1:3); %remove translation
        R3 = R3(1:3,1:3); %remove translation
        R = R3*R1; % Total rotation

        % Rotation matrix force plate to coordinate system used in c3d file
        R_FPa = roty(1*pi); % rotate 180degrees y
        R_FPa = R_FPa(1:3,1:3);
        R_FPb =  rotz(0.5*pi); % rotate 180degrees z
        R_FPb = R_FPb(1:3,1:3);
        R_FP = R_FPa*R_FPb;

        % Rotate all force plates
        RotMatz = rotz(0.5*pi); % 90degrees rot matrix
        R_FP1 = R_FP*RotMatz(1:3,1:3); % turn

        RotMatz = rotz(1.5*pi); % 270degrees rot matrix
        R_FP2 = R_FP*RotMatz(1:3,1:3); % turn

    case {'LKHG_Cleve', 'LKHG_PiG'} % has four plates
        % Rotation matrix from c3d to OpenSim for Markers
        R1 = rotx(0.5*pi); %rotate 90degrees around X
        R3 = rotz(pi); %rotate 180degrees around z
        R1 = R1(1:3,1:3); %remove translation
        R3 = R3(1:3,1:3); %remove translation
        R = R3*R1; % Total rotation

        % Rotation matrix force plate to coordinate system used in c3d file
        R_FPa = roty(1*pi); % rotate 180degrees y
        R_FPa = R_FPa(1:3,1:3);
        R_FPb =  rotz(0.5*pi); % rotate 180degrees z
        R_FPb = R_FPb(1:3,1:3);
        R_FP = R_FPa*R_FPb;

        % Rotate all force plates
        RotMat = rotz(1.5*pi); % 270degrees rot matrix
        R_FP1 = R_FP*RotMat(1:3,1:3);
        R_FP2 = R_FP*RotMat(1:3,1:3);
        R_FP3 = R_FP*RotMat(1:3,1:3);
        R_FP4 = R_FP*RotMat(1:3,1:3);

    case 'PLUS_COD_noArms'
          % Rotation matrix from c3d to OpenSim for Markers
          R1 = rotx(0.5*pi);  % rotate 90° around x
          R2 = roty(pi);      % rotate 180° around y
          R3 = rotz(pi);      % rotate 180° around z
          R1 = R1(1:3,1:3);   % remove translation
          R2 = R2(1:3,1:3);   % remove translation
          R3 = R3(1:3,1:3);   % remove translation
          R = R3*R2*R1;       % Total rotation

          % Rotation matrix force plate to coordinate system used in c3d file
          R_FPa = rotz(0.5*pi); % 90° Drehung um die Z-Achse (Y wird zu -X, X wird zu Y)
          % R_FPb = rotz(0.5*pi);   % rotate 90° z % Huthöfer --> ursprünglich: 
          R_FPb = rotx(pi); % 180° Drehung um die X-Achse (Z wird von negativ zu positiv umgekehrt)
          R_FPa = R_FPa(1:3,1:3); % remove translation
          R_FPb = R_FPb(1:3,1:3); % remove translation
          R_FP = R_FPa*R_FPb;     % Total rotation % % Reihenfolge ist wichtig, zuerst R_FPa, dann R_FPb

          % Rotate all force plates
          RotMat = rotz(0.5*pi);  % turn 90° um Z - RotMat is a Matrix for individualised turning of each ForcePlates - in this case. R_FP1
          RotMat = RotMat(1:3,1:3);
          R_FP1 = R_FP*RotMat; 
          R_FP2 = R_FP; 
          % R_FP3 = R_FP*RotMat(1:3,1:3);   % turn
          % R_FP4 = R_FP*RotMat(1:3,1:3);   % turn
          % R_FP5 = R_FP*RotMat(1:3,1:3);   % turn
          % R_FP6 = R_FP; %
          % R_FP7 = R_FP; %

    case 'PLUS_SportsMarkerset_noArms'
        % Rotation matrix from c3d to OpenSim for Markers
        R1 = rotx(0.5*pi);  % rotate 90° around x
        R2 = roty(pi);      % rotate 180° around y
        R3 = rotz(pi);      % rotate 180° around z
        R1 = R1(1:3,1:3);   % remove translation
        R2 = R2(1:3,1:3);   % remove translation
        R3 = R3(1:3,1:3);   % remove translation
        R = R3*R2*R1;       % Total rotation
        
        % Rotation matrix force plate to coordinate system used in c3d file
        R_FPa = rotz(0.5*pi); % 90° Drehung um die Z-Achse (Y wird zu -X, X wird zu -Y)
        R_FPb = rotx(pi); % 180° Drehung um die X-Achse (Z wird von negativ zu positiv umgekehrt)
%         R_FPc = rotz(-0.5*pi); % ergänzt jh
        R_FPa = R_FPa(1:3,1:3); % remove translation
        R_FPb = R_FPb(1:3,1:3); % remove translation
%         R_FPc = R_FPc(1:3,1:3);
        R_FP = R_FPa*R_FPb;     % Total rotation % % Reihenfolge ist wichtig, zuerst R_FPa, dann R_FPb
        
        % Rotate all force plates
        RotMat = rotz(1.5*pi);  % turn 270° (geändert von 90°) um Z - RotMat is a Matrix for individualised turning of each ForcePlates - in this case. R_FP1
        RotMat = RotMat(1:3,1:3);
        R_FP1 = R_FP*RotMat; 
        R_FP2 = R_FP*RotMat;  % *RotMat ergänzt.
        % R_FP3 = R_FP*RotMat(1:3,1:3);   % turn
        % R_FP4 = R_FP*RotMat(1:3,1:3);   % turn
        % R_FP5 = R_FP*RotMat(1:3,1:3);   % turn
        % R_FP6 = R_FP; %
        % R_FP7 = R_FP; %

    case 'PLUS_SportsMarkerset_noArms_newFPs'
        % Rotation matrix from c3d to OpenSim for Markers
        R1 = rotx(0.5*pi);  % rotate 90° around x
        R2 = roty(pi);      % rotate 180° around y
        R3 = rotz(pi);      % rotate 180° around z
        R1 = R1(1:3,1:3);   % remove translation
        R2 = R2(1:3,1:3);   % remove translation
        R3 = R3(1:3,1:3);   % remove translation
        R = R3*R2*R1;       % Total rotation
        
        % Rotation matrix force plate to coordinate system used in c3d file
        %{
        R_FPa = rotz(1.5*pi); % 90° Drehung um die Z-Achse (Y wird zu -X, X wird zu -Y)
        R_FPb = rotx(pi); % 180° Drehung um die X-Achse (Z wird von negativ zu positiv umgekehrt)
%         R_FPc = rotz(-0.5*pi); % ergänzt jh
        R_FPa = R_FPa(1:3,1:3); % remove translation
        R_FPb = R_FPb(1:3,1:3); % remove translation
%         R_FPc = R_FPc(1:3,1:3);
        R_FP = R_FPa*R_FPb;     % Total rotation % % Reihenfolge ist wichtig, zuerst R_FPa, dann R_FPb
        
        % Rotate all force plates
        RotMat = rotz(0.5*pi);  % turn 270° (geändert von 90°) um Z - RotMat is a Matrix for individualised turning of each ForcePlates - in this case. R_FP1
        RotMat = RotMat(1:3,1:3);
        R_FP1 = R_FP*RotMat; 
        R_FP2 = R_FP*RotMat;  % *RotMat ergänzt.
        % R_FP3 = R_FP*RotMat;  % *RotMat ergänzt.
        % R_FP3 = R_FP*RotMat(1:3,1:3);   % turn
        % R_FP4 = R_FP*RotMat(1:3,1:3);   % turn
        % R_FP5 = R_FP*RotMat(1:3,1:3);   % turn
        % R_FP6 = R_FP; %
        % R_FP7 = R_FP; %
        %}
		
        % Define Force Plate rotations
        R_FP1 = roty(pi);       
        R_FP1 = R_FP1(1:3,1:3);
        
        R_FP2a = rotx(pi);
        R_FP2b = rotz(-0.5*pi);
        R_FP2  = R_FP2b * R_FP2a;
        R_FP2  = R_FP2(1:3,1:3);
        
        R_FP3a = rotx(pi);
        R_FP3b = rotz(-0.5*pi);
        R_FP3  = R_FP3b * R_FP3a;
        R_FP3  = R_FP3(1:3,1:3);

    otherwise
        warning('Unknown labFlag: %s in c3d2OpenSim. Skript paused!', labFlag);
        pause()
end

%% Export markers

% Read c3d file with btk.
acq = btkReadAcquisition(c3dfile);

% Get acq data.
VideoFrameRate = btkGetPointFrequency(acq);
AnalogFrameRate = btkGetAnalogFrequency(acq);
f = btkGetForcePlatforms(acq);

% Get c3d cam delta.
metaData = btkGetMetaData(acq);
% cam_rate = metaData.children.TRIAL.children.CAMERA_RATE.info.values(1,1);
% startfield = metaData.children.TRIAL.children.ACTUAL_START_FIELD.info.values(1,1);

% % % holder: adapted (23.10.2024)
cam_rate = metaData.children.POINT.children.RATE.info.values(1,1);
startfield = metaData.children.POINT.children.DATA_START.info.values(1,1);
% % % 
delta = 1/cam_rate * startfield;

% Get all Marker data.
markers_out = btkGetMarkers(acq);

% Get all Marker data labels.
fn = fieldnames(markers_out);

% Now reduce to the set of available markers to the ones specified in the
% markerSet.
k = 1;
for i = 1:size(fn,1)
    temp{i} = fn{i};

    % Check if marker is in the list of the marker set.
    if sum(ismember(markerSet,fn{i})) == 1

        % Write reduced marker set.
        tempMLabels{k} = fn{i};

        if i == 1
            tempMarkers(1:size(markers_out.(fn{k}),1),1:3)= markers_out.(fn{i});
        else
            tempMarkers(1:size(markers_out.(fn{k}),1),((k-1)*3)+1:((k-1)*3)+3)= markers_out.(fn{i});
        end
        k = k + 1;
    end
end

% Make sure facing direction is always in the same dircetion for all trials.
% For this we use the vector from the SCAR to the midASIS as indicator.
% Seestart file for specifications of "pelvisMarker4nonUniformScaling" (= pelvisMarker):

try
    if length(pelvisMarker) == 6
        SACR = (markers_out.(pelvisMarker{5}) + markers_out.(pelvisMarker{6}))./2;
    else
        SACR = markers_out.(pelvisMarker{5});
    end

    % midAsis = (markers_out.(pelvisMarker{1}) + markers_out.(pelvisMarker{2}))./2;
    % faceDirection = midAsis(1,1:2) - SACR(1,1:2); % only x and y
    % % % holder: adapted (23.10.2024)
    midAsis = (markers_out.WaistLFront + markers_out.WaistRFront)./2; 
    faceDirection = midAsis(1,1:2) - markers_out.WaistBack(1,1:2);
    % % %    
    x_faceDir = faceDirection(1);
    y_faceDir = faceDirection(2);

    if x_faceDir > 0 && y_faceDir > 0 % QI

        if y_faceDir > x_faceDir % subject looks NNE
            % turn 90 clockwise
            R_correction = rotz(-0.5*pi);
        elseif y_faceDir < x_faceDir % subject looks E (this is what we want!)
            % do nothing!
            R_correction = rotz(0);
        end

    elseif x_faceDir > 0 && y_faceDir < 0 % QII

        if abs(y_faceDir) > x_faceDir % subject looks SSE
            % turn 90 anti-clockwise
            R_correction = rotz(0.5*pi);
        elseif abs(y_faceDir) < x_faceDir % subject looks E (this is what we want!)
            % do nothing!
            R_correction = rotz(0);
        end

    elseif x_faceDir < 0 && y_faceDir < 0 % QIII

        if abs(y_faceDir) > abs(x_faceDir) % subject looks SSW
            % turn 90 anti-clockwise
            R_correction = rotz(0.5*pi);
        elseif abs(y_faceDir) < abs(x_faceDir) % subject looks WSW
            % turn 180
            R_correction = rotz(pi);
        end

    elseif x_faceDir < 0  && y_faceDir > 0 % QIV

        if y_faceDir > abs(x_faceDir) % subject looks NNW
            % turn +90 clockwise
            R_correction = rotz(-0.5*pi);
        elseif y_faceDir < abs(x_faceDir) % subject looks WNW
            % turn 180
            R_correction = rotz(pi);
        end

    end

    % Create correction rot. matrix.
    R_correction = R_correction(1:3,1:3); %remove translation

catch
    % In case something went wrong catch error and create a matrix that
    % does not do anything.
    R_correction = rotz(0);
    R_correction = R_correction(1:3,1:3); %remove translation
end

% Apply correction to rot. matrix for markers (R).
R = R * R_correction;

% Now rotate markers.
Markers = rot3DVectors(R, tempMarkers);
Markers = Markers * 0.001;          % convert from mm to m
MLabels = tempMLabels;

% Create additional info.
[nvF, ~] = size(Markers);           % get number of frames
vFrms = (1:nvF)';                   % frame index
vTime = (1/VideoFrameRate*(vFrms)) + delta; % Time vector starting with delta from c3d startingfield

writeMarkersToTRC(TRC_out, Markers, MLabels, VideoFrameRate, vFrms, vTime, 'm');  % write to TRC file

%% Export GRF
% Note that this a bit more difficult if the COP is not yet computed and
% stored in the .c3d file (Lines below only needed for computation of the
% COP).

% Get the FP information in the c3d file.
nFP = length(f);  % get number of FP

% Convert corners and origin from mm to m if needed.
for I = 1:nFP
    f(I).corners = 0.001*f(I).corners;
    f(I).origin = 0.001*f(I).origin;
end

% Compute COP location & create output matrix.
nFR = btkGetAnalogFrameNumber(acq);
FP_DatOut = zeros(nFR,nFP*9);

for i = 1:nFP

    % Select rotation matrix.
    R_FP =  eval(['R_FP' num2str(i)]);

    % Get the forces in a generative way in case of different naming.
    % conventions
    ForcesNameCell = fieldnames(f(i).channels);
    ForceName_x = char(ForcesNameCell(1));
    ForceName_y = char(ForcesNameCell(2));
    ForceName_z = char(ForcesNameCell(3));
    MomentName_x = char(ForcesNameCell(4));
    MomentName_y = char(ForcesNameCell(5));
    MomentName_z = char(ForcesNameCell(6));

    % Now convert moments to Nm as we did before for the FP corners.
    Fx_raw = f(i).channels.(ForceName_x);
    Fy_raw = f(i).channels.(ForceName_y);
    Fz_raw = f(i).channels.(ForceName_z);
    Mx_raw = f(i).channels.(MomentName_x).*0.001; % convert to Nm;
    My_raw = f(i).channels.(MomentName_y).*0.001; % convert to Nm;
    Mz_raw = f(i).channels.(MomentName_z).*0.001; % convert to Nm;

    % Low pass filter of GRF.
    fc = 12;
    [a,b] = butter(4,fc/(AnalogFrameRate*0.5),'low');
    % % added by jh (10.11.2025)
    if any(isnan(Fx_raw)) || any(isnan(Fy_raw)) || any(isnan(Fz_raw))
        Fx_raw(isnan(Fx_raw)) = 0;
        Fy_raw(isnan(Fy_raw)) = 0;
        Fz_raw(isnan(Fz_raw)) = 0;
        Mx_raw(isnan(Mx_raw)) = 0;
        My_raw(isnan(My_raw)) = 0;
        Mz_raw(isnan(Mz_raw)) = 0;
    end
    % % %  

    Fx = filtfilt(a,b,Fx_raw);
    Fy = filtfilt(a,b,Fy_raw);
    Fz = filtfilt(a,b,Fz_raw);
    Mx = filtfilt(a,b,Mx_raw);
    My = filtfilt(a,b,My_raw);
    Mz = filtfilt(a,b,Mz_raw);

    % Get vertical distance between surface and origin FP.
    dz = -1 * f(i).origin(3);

    % Get the COP and free moment around vertical axis.
    COPx = (-1*My + dz*Fx)./Fz;
    COPy = (Mx + dz*Fy)./Fz;
    Tz = Mz + COPy.*Fx - COPx.*Fy;
    
    % Ergänzung - Jana 19.02.2026
    if i == 1
        R_FP = R_FP1;
    elseif i == 2
        R_FP = R_FP2;
    elseif i == 3
        R_FP = R_FP3;
    end

    % Rotate FP info to correct coordinate system.
    Fsel = [Fx Fy Fz];                   % forces
    Tsel = [zeros(length(Tz),2) Tz];     % free moment
    Flab = rot3DVectors(R_FP,Fsel);      % rotate forces to lab frame
    Tlab = rot3DVectors(R_FP,Tsel);      % rotate moments to lab frame
    Frot = rot3DVectors(R,Flab);         % rotate forces from lab to Osim
    Trot = rot3DVectors(R,Tlab);

    % Get location COP in world frame.
    pFP_lab = sum(f(i).corners')./4;                    % get position vector from lab to origin FP
    pFP_origin = f(i).origin';                          % FP surface to FP origin
    pFP_origin_rot = (R_FP * pFP_origin');              % rotate this vector to world frame
    COP = [COPx COPy ones(nFR,1).*-pFP_origin(3)];      % Matrix with COP info
    COP_or_lab = R_FP * COP';                           % rotate COP to lab

    COP_lab = ones(nFR,1)*pFP_lab + ones(nFR,1)*pFP_origin_rot' + COP_or_lab';   % add location FP in lab to COP position
    COProt = rot3DVectors(R,COP_lab);

    % Trim COP information with Fthreshold because the COP is not reliable
    % if forces are low.
    ind=find(Frot(:,2)<5); % This is a low threshold because I create the events later with a threshold of >10N.
    for j=1:3
        COProt(ind,j) = 0;
        Frot(ind,j) = 0;
        Trot(ind,j) = 0;
    end

    % Store all the information.
    FP_DatOut(:,i*6-5:i*6-3) = Frot;              % 1-3 = Force
    FP_DatOut(:,i*6-2:i*6) = COProt;              % 4-6 = COP
    FP_DatOut(:,nFP*6+i*3-2:nFP*6+i*3) = Trot;    % Store Free moments after all the Force and COP information
end

% Create header file.
labels=[];
for i=1:nFP
    fp_nr =[num2str(i) '_'];
    labels{i*6-5} = ['ground_force_' fp_nr 'vx'];
    labels{i*6-4} = ['ground_force_' fp_nr 'vy'];
    labels{i*6-3} = ['ground_force_' fp_nr 'vz'];
    labels{i*6-2} = ['ground_force_' fp_nr 'px'];
    labels{i*6-1} = ['ground_force_' fp_nr 'py'];
    labels{i*6}   = ['ground_force_' fp_nr 'pz'];
    labels{nFP*6 + i*3-2} = ['ground_torque_' fp_nr 'x'];
    labels{nFP*6 + i*3-1} = ['ground_torque_' fp_nr 'y'];
    labels{nFP*6 + i*3}   = ['ground_torque_' fp_nr 'z'];
end

% Export the GRF file.
t_vect = ((1:nFR)./AnalogFrameRate) + delta;
generateMotFile([t_vect' FP_DatOut], ['time' labels],GRF_out);

% Now close acq.
btkCloseAcquisition(acq);

%% Clear variables except output to prevet memory leak.
clearvars -except TRC_out GRF_out
end

