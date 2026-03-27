function add_JC_to_TRC_for_scaling(trc_input_file, trc_output_file, jc_base_data)
%__________________________________________________________________________
% Author: Hans Kainz, April 2017
% adapted by brian.horsak@ustp.at (02/2026)
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
%__________________________________________________________________________

MarkerDiameter = 14; %#ok<NASGU>

% Read trc file
acq     = btkReadAcquisition(trc_input_file);
markers = btkGetMarkers(acq);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Resolve marker names dynamically
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Hip / pelvis
RASI = markers.(jc_base_data.hip(1));
LASI = markers.(jc_base_data.hip(2));

if length(jc_base_data.hip) == 3
    use_sac = true;
    MidPSIS = markers.(jc_base_data.hip(3));
else
    use_sac = false;
    RPSI = markers.(jc_base_data.hip(3));
    LPSI = markers.(jc_base_data.hip(4));
end

% Knee (hard-coded positional meaning)
LKNE  = markers.(jc_base_data.knee(1));
LMKNE = markers.(jc_base_data.knee(2));
RKNE  = markers.(jc_base_data.knee(3));
RMKNE = markers.(jc_base_data.knee(4));

% Ankle (hard-coded positional meaning)
LANK = markers.(jc_base_data.ankle(1));
LMM  = markers.(jc_base_data.ankle(2));
RANK = markers.(jc_base_data.ankle(3));
RMM  = markers.(jc_base_data.ankle(4));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Leg Lenght (LL)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%  RIGHT
d_RASI_RMKNE = sqrt(sum((RASI - RMKNE).^2, 2));   % Nx1
d_RMKNE_RMM  = sqrt(sum((RMKNE - RMM).^2, 2));    % Nx1
right_leg_length = d_RASI_RMKNE + d_RMKNE_RMM;    % Nx1 (meters)
LLR = mean(right_leg_length);

% LEFT
d_LASI_LMKNE = sqrt(sum((LASI - LMKNE).^2, 2));   % Nx1
d_LMKNE_LMM  = sqrt(sum((LMKNE - LMM).^2, 2));    % Nx1
left_leg_length = d_LASI_LMKNE + d_LMKNE_LMM;     % Nx1 (meters)
LLL = mean(left_leg_length);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Knee & Ankle Joint Centers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

LKJC = (LKNE + LMKNE) / 2;
RKJC = (RKNE + RMKNE) / 2;
LAJC = (LANK + LMM) / 2;
RAJC = (RANK + RMM) / 2;

JointCenters.LKJC = LKJC;
JointCenters.RKJC = RKJC;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% AJC_offset (Bruening et al., 2008)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% HJC estimation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% MidPSIS if no SAC
if ~use_sac
    MidPSIS = (RPSI+LPSI)/2;
end

MidASIS = (RASI+LASI)/2;

switch lower(jc_base_data.method)
    case "hara"
        % ----------- Hara et al. (with LL in mm)
        LLRmm = LLR *1000;
        LLLmm = LLL *1000;

        %   Define the pelvis origin
        MidASIS = (RASI+LASI)/2;
        originPelvis=MidASIS;
        for t=1:length(RASI)
            % HJC definition based Hara et al. (with LL in mm)
            H_ap_mm_r = 11 - 0.063 * LLRmm;
            H_v_mm_r = -9 - 0.078*LLRmm;
            H_ml_mm_r = 8 + 0.086 * LLRmm;

            % Convert back to meters
            H_ap_r = H_ap_mm_r / 1000;
            H_v_r  = H_v_mm_r  / 1000;
            H_ml_r = H_ml_mm_r / 1000;


            RHJC_Hara(t,:) = horzcat(H_ap_r,H_v_r,H_ml_r);


            % HJC definition based Hara et al. (with LL in mm)
            H_ap_mm_l = 11 - 0.063 * LLLmm;
            H_v_mm_l = -9 - 0.078*LLLmm;
            H_ml_mm_l = 8 + 0.086 * LLLmm * -1; %for left side * -1

            % Convert back to meters
            H_ap_l = H_ap_mm_l / 1000;
            H_v_l  = H_v_mm_l  / 1000;
            H_ml_l = H_ml_mm_l / 1000;

            LHJC_Hara(t,:) = horzcat(H_ap_l,H_v_l,H_ml_l);

            %   Calculate unit vectors of Pelvis segment relative to global
            [e1Pelvis,e2Pelvis,e3Pelvis]=segmentorientation_1Frame(originPelvis(t,:)-MidPSIS(t,:),RASI(t,:)-LASI(t,:));
            rotationmatrix=[e1Pelvis;e2Pelvis;e3Pelvis];
            RHJC(t,:)=(mldivide(rotationmatrix,(RHJC_Hara(t,:)'))+originPelvis(t,:)')';
            LHJC(t,:)=(mldivide(rotationmatrix,(LHJC_Hara(t,:)'))+originPelvis(t,:)')';
            rotationmatrix=[];
        end

    case "harrington_single"

        % Harrington et al.
        ASISvector=LASI-RASI;
        ASISdistance=sqrt((ASISvector(1,1))^2+(ASISvector(1,2))^2+(ASISvector(1,3))^2);

        PW=ASISdistance*1000; % convert to mm since regression expects mm.

        %   Define the pelvis origin
        originPelvis=MidASIS;
        for t=1:length(RASI)
            % HJC definition based on modified Harrington equations (global
            % coordinates) Sangeux, 2015
            H_ap_mm = -0.138*PW - 10.4;
            H_v_mm = -0.305*PW - 10.9;
            H_ml_mm = 0.33*PW + 7.3;

            % Convert back to meters
            H_ap = H_ap_mm / 1000;
            H_v  = H_v_mm  / 1000;
            H_ml = H_ml_mm / 1000;
            H_ml_left = -H_ml;

            RHJC_Harringtion(t,:) = horzcat(H_ap,H_v,H_ml);
            LHJC_Harringtion(t,:) = horzcat(H_ap,H_v,H_ml_left);

            %   Calculate unit vectors of Pelvis segment relative to global
            [e1Pelvis,e2Pelvis,e3Pelvis]=segmentorientation_1Frame(originPelvis(t,:)-MidPSIS(t,:),RASI(t,:)-LASI(t,:));
            rotationmatrix=[e1Pelvis;e2Pelvis;e3Pelvis];
            RHJC(t,:)=(mldivide(rotationmatrix,(RHJC_Harringtion(t,:)'))+originPelvis(t,:)')';
            LHJC(t,:)=(mldivide(rotationmatrix,(LHJC_Harringtion(t,:)'))+originPelvis(t,:)')';
            rotationmatrix=[];
        end
    
    otherwise
        warning("HJC estimation method not defined.")
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Append markers to TRC
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

newMarkers = {RHJC, LHJC, RKJC, LKJC, RAJC_offset, LAJC_offset};
newLabels  = {'RHJC','LHJC','RKJC','LKJC','RAJC','LAJC'};

appendMarkersToTRC(trc_input_file, trc_output_file, newMarkers, newLabels);

end