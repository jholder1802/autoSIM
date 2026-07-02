 function [path2adjustedModel, tf_angle_out, tf_angle_fromSource_out] = adjustFrontAlignmentModel(path2scaledModel, path2plugIn, tf_angle_manual, side, tf_angle_fromSource,...
    static, BodyHeight, bodymass, persInfo, useStatic4FrontAlignmentAsFallback, rootWorkingDirectory, varNameKneeAngle_c3d, varNameKneeAngle_c3d_posFront)

% This file adapts a *.osim model and changes the frontal alignment of the
% proximal tibia and distal femur body.
%
% Written by:           Brian Horsak - brian.horsak@fhstp.ac.at
% Acknowledgements:     Many thx to Bryce Killian (KU Leuven) for his great
%                       support
%
% Last changed:         09/2025
% -------------------------------------------------------------------------

% Specify the current body side.
sideLong = char(lower(side));
side = char(sideLong(1));

% Read model personalization info
dataFile = fullfile(rootWorkingDirectory, 'data.xml');
if isfile(dataFile)
    persInfo = readstruct(dataFile);
    
    % Check if the personalization data in persInfo can be used based on
    % the examination date. Otherwise skip. The difference should be below 30
    % days for TF.
    tibFemOk = checkIfExternalDataIsValid(persInfo, 'XRAYdate', 'EXAMINATIONdate', 14);
else
    persInfo = ''; % just to have the variable.
    tibFemOk = false;
end

% Now proceed with rest.
if strcmpi(tf_angle_fromSource, 'false')
    path2adjustedModel = path2scaledModel;
    tf_angle_fromSource_out = tf_angle_fromSource;
    tf_angle_out = 0;

else

    % Check if user selected external data file and data file exists and if data can be used.
    if strcmpi(tf_angle_fromSource, 'fromExtDataFile') && ~isempty(persInfo) && tibFemOk

        if strcmpi(tf_angle_fromSource, 'fromExtDataFile') && ~isnan(persInfo.(strcat('XRAY_FT_angle_degree_', sideLong)))
            % Check if info in dataFiles is available and what user decided. In
            % case 'fromExtDataFile' is selected but no info is available in the
            % external file the function will jump to 'fromStatic'.

            % Valgus/Varus info is available. Will be fetched from source.
            tf_angle_used = round(persInfo.(strcat('XRAY_FT_angle_degree_', sideLong)),1);
            tf_angle_fromSource_out = tf_angle_fromSource;

        elseif (strcmpi(tf_angle_fromSource, 'fromExtDataFile') && isnan(persInfo.(strcat('XRAY_FT_angle_degree_', sideLong))))

            % In case the from ext. does not contain info, this will be the
            % fallback.
            if useStatic4FrontAlignmentAsFallback
                tf_angle_used = getTFangleFromDirKinemStatic(static, varNameKneeAngle_c3d_posFront, varNameKneeAngle_c3d);
                tf_angle_fromSource_out = 'fromStatic';
            else
                tf_angle_used = 0;
                tf_angle_fromSource_out = 'false';
            end

        elseif strcmpi(tf_angle_fromSource, 'fromStatic')
            tf_angle_used = getTFangleFromDirKinemStatic(static, varNameKneeAngle_c3d_posFront, varNameKneeAngle_c3d);
            tf_angle_fromSource_out = tf_angle_fromSource;

        end
    else
        % In case the ext. file does not exist or data cannot be used, this will be the fallback.
        if strcmpi(tf_angle_fromSource, 'manual')
            tf_angle_used = tf_angle_manual;
            tf_angle_fromSource_out = tf_angle_fromSource;

        elseif useStatic4FrontAlignmentAsFallback
            tf_angle_used = getTFangleFromDirKinemStatic(static, varNameKneeAngle_c3d_posFront, varNameKneeAngle_c3d);
            tf_angle_fromSource_out = 'fromStatic';
        else
            tf_angle_used = 0;
            tf_angle_fromSource_out = 'false';
        end
    end

    if strcmpi(tf_angle_fromSource, 'false')
        % In case we did not set the fallback solution to true.
        path2adjustedModel = path2scaledModel;
        tf_angle_fromSource_out = tf_angle_fromSource;
        tf_angle_out = 0;

    else

        % Tf angle for output before calculating it in rad and before *-1 for left side
        tf_angle_out = tf_angle_used;

        % Prepare angle correction depending if it is a right or a left model
        if strcmpi(side(1), 'l')
            tf_angle_used = tf_angle_used * -1;
        end

        % Calculate radians from deg
        tf_angle_used_rad = tf_angle_used * pi/180;

        % Load the API, and jam plugin
        import org.opensim.modeling.*
        opensimCommon.LoadOpenSimLibrary(path2plugIn);

        % Create a copy of the scaled model, change name, and create output path
        [filepath,name,ext] = fileparts(path2scaledModel);
        path2Model2Adjust = strcat(filepath,'\',name,'-tf', ext); % <-- This is the output of this function
        copyfile(path2scaledModel,path2Model2Adjust);

        % Change the tibio-femoral alignment in the specified model.
        % Load model
        model = Model(path2Model2Adjust);

        % Get tibia proximal body and change frontal orientation. Make
        % change 50% at femur and 50% at tibia segment
        femJointSet = model.get_JointSet.get(strcat('femur_femur_distal_', side));
        femFrame = femJointSet.get_frames(0); % there is only one frame
        tf_angleOsim = ArrayDouble.createVec3([tf_angle_used_rad * 0.5 ,0,0]);
        femFrame.set_orientation(tf_angleOsim);

        tibJointSet = model.get_JointSet.get(strcat('tibia_tibia_proximal_', side));
        tibFrame = tibJointSet.get_frames(0); % there is only one frame
        tf_angleOsim = ArrayDouble.createVec3([tf_angle_used_rad * 0.5 ,0,0]);
        tibFrame.set_orientation(tf_angleOsim);

        % Save model
        model.print(path2Model2Adjust);
        path2adjustedModel = path2Model2Adjust;

    end
end

%% Clear variables except output to prevet memory leak.
clearvars -except path2adjustedModel tf_angle_out tf_angle_fromSource_out
end