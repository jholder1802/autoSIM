%__________________________________________________________________________
% Author: Hans Kainz, April 2017
% email: hans.kainz@kuleuven.be
% adapted by brian.horsak@ustp.at (02/2026)
%
% this code can be used to add the required virtual markers to the trc/c3d file for the
% recommended scaling approaches from Kainz et al., 2017.
%
% this code adds virtual joint centre marker to the trc/c3d file using the modified HJC
% from Harrington et al., 2007/Sangeux, 2015 (Harrington regression equations with only pelvis width as input), KJC midpoint between med and lat knee markers,
% AJC midpoint med and lat ankle marker including the offset defined in Bruening et al., 2008
%
% Kainz et al., 2017, Accuracy and Reliability of Marker Based Approaches to Scale the Pelvis, Thigh and
% Shank Segments in Musculoskeletal Models, Journal of Applied
% Biomechanics ().
%
% Harrington et al., 2007, Prediction of the hip joint centre in adults,
% children, and patient with cerebral palsy based on magnetic resonance
% imaging. Journal of Biomechanics, 40(3):595-602.
%
% Sangeux, 2015, On the implementation of predictive methods to locate the
% hip joint centres, Gait and Posture, 42(3):402-5.
%
% Bruening et al., 2008, A simple, anatomically based correction to the
% conventional ankle joint center. Clinical Biomechanics, 23(10): 1299-302.
% _________________________________________________________________________
%


function JointCenters = AddJCtoTRC_forScaling(trc_input_file, trc_output_file, marker_names)
%filepath=which('AddJCtoTRC_forScaling.m'); [MainDir,~,~]=fileparts(filepath);

MarkerDiameter = 14;   % check marker diameter

% Read trc file
acq = btkReadAcquisition(trc_input_file);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Check marker names
markers = btkGetMarkers(acq);
LASI=markers.LASI;
RASI=markers.RASI;

if length(marker_names.hip) == 3
    use_sac = true;
else
    use_sac = false;
end

if use_sac
    MidPSIS = markers.SACR; % use this if you have a SACR instead of LPSI and RPSI markers
else

    RPSI=markers.RPSI;
    LPSI=markers.LPSI;
end

LKNE=markers.LKNE;
LMKNE=markers.LMKNE;
LANK=markers.LANK;
LMM=markers.LMMA;

RKNE=markers.RKNE;
RMKNE=markers.RMKNE;
RANK=markers.RANK;
RMM=markers.RMMA;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
LKJC=(LKNE+LMKNE)/2;
RKJC=(RKNE+RMKNE)/2;
LAJC=(LANK+LMM)/2;
RAJC=(RANK+RMM)/2;
JointCenters.LKJC=LKJC;
JointCenters.RKJC=RKJC;

% Add AJC_offset marker based on Bruening et al., 2008
% right AJC_offset
SL=RKJC-RAJC;
SL_distance=sqrt( SL(1,1)*SL(1,1)+SL(1,2)*SL(1,2)+SL(1,3)*SL(1,3) );
offset = 0.027*SL_distance;
for t=1:length(RKJC)
    originRTibia=RAJC;
    [e1TibiaR,e2TibiaR,e3TibiaR]=segmentorientation_r(RKJC(t,:)-RAJC(t,:),RANK(t,:)-RAJC(t,:));
    rotationmatrix_1=[e1TibiaR;e2TibiaR;e3TibiaR];
    RAJC_offset_rTibia(t,:)=[-offset 0 0];
    RAJC_offset(t,:)=(mldivide(rotationmatrix_1,(RAJC_offset_rTibia(t,:)'))+originRTibia(t,:)')';
    JointCenters.RAJC(t,:)=RAJC_offset(t,:);
end

% left AJC_offset
SL_left=LKJC-LAJC;
SL_left_distance=sqrt( SL_left(1,1)*SL_left(1,1)+SL_left(1,2)*SL_left(1,2)+SL_left(1,3)*SL_left(1,3) );
offset_left = 0.027*SL_left_distance;
for t=1:length(LKJC)
    originLTibia=LAJC;
    [e1TibiaL,e2TibiaL,e3TibiaL]=segmentorientation_l(LKJC(t,:)-LAJC(t,:),LANK(t,:)-LAJC(t,:));
    rotationmatrix_2=[e1TibiaL;e2TibiaL;e3TibiaL];
    LAJC_offset_lTibia(t,:)=[-offset_left 0 0];
    LAJC_offset(t,:)=(mldivide(rotationmatrix_2,(LAJC_offset_lTibia(t,:)'))+originLTibia(t,:)')';
    JointCenters.LAJC(t,:)=LAJC_offset(t,:);
end

% Add Harrington HJC
ASISvector=LASI-RASI;
ASISdistance=sqrt((ASISvector(1,1))^2+(ASISvector(1,2))^2+(ASISvector(1,3))^2);

if ~use_sac
MidPSIS = (RPSI+LPSI)/2;
end

MidASIS = (RASI+LASI)/2;

PW=ASISdistance;

%   Define the pelvis origin
originPelvis=MidASIS;
for t=1:length(RASI)
    % HJC definition based on modified Harrington equations (global
    % coordinates) Sangeux, 2015
    H_ap=-0.138*PW-10.4;
    H_v=-0.305*PW-10.9;
    H_ml=0.33*PW+7.3;
    H_ml_left=-H_ml;
    RHJC_Harringtion(t,:) = horzcat(H_ap,H_v,H_ml);
    LHJC_Harringtion(t,:) = horzcat(H_ap,H_v,H_ml_left);

    %   Calculate unit vectors of Pelvis segment relative to global
    [e1Pelvis,e2Pelvis,e3Pelvis]=segmentorientation_1Frame(originPelvis(t,:)-MidPSIS(t,:),RASI(t,:)-LASI(t,:));
    rotationmatrix=[e1Pelvis;e2Pelvis;e3Pelvis];
    RHJC(t,:)=(mldivide(rotationmatrix,(RHJC_Harringtion(t,:)'))+originPelvis(t,:)')';
    LHJC(t,:)=(mldivide(rotationmatrix,(LHJC_Harringtion(t,:)'))+originPelvis(t,:)')';
    JointCenters.RHJC(t,:)=RHJC(t,:);
    JointCenters.LHJC(t,:)=LHJC(t,:);
    rotationmatrix=[];
end

% Add marker to trc file
btkAppendPoint(acq, 'marker', 'RHJC_test', RHJC)
btkAppendPoint(acq, 'marker', 'LHJC_test', LHJC)
btkAppendPoint(acq, 'marker', 'RKJC_test', RKJC)
btkAppendPoint(acq, 'marker', 'LKJC_test', LKJC)
btkAppendPoint(acq, 'marker', 'RAJC_test', RAJC_offset)
btkAppendPoint(acq, 'marker', 'LAJC_test', LAJC_offset)

% cd(NewTrcFile_folder)
btkWriteAcquisition(acq, trc_output_file);

% Clear memory
btkDeleteAcquisition(acq)
RHJC=[];
RKJC=[];
RAJC=[];
LHJC=[];
LKJC=[];
LAJC=[];

