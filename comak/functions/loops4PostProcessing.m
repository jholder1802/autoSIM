function loops4PostProcessing(rootDirectory, workingDirectories, conditions, path2setupFiles, prefix, timeNormFlag, catchErrors, trialType, pipelineName, processVtp, useParallelToolBox, M)

% Start timer
tStart = tic;

%% Run pipelines
disp('>>>>> Starting to postprocess the data ...');

% Add loops here:

if useParallelToolBox 
    nWorkers = M;
else
    nWorkers = 0; % Huthöfer: habe 1 statt 0 geschrieben % default: 0
end

% Initialize count for catched errors.
errN = 0; % Number of errors occured and catched

% Loop Folders
% parfor (wd = 1 : length(workingDirectories), nWorkers) % % geändert zum debuggen, jh (10.11.2025)
for wd = 1 : length(workingDirectories)
    % Loop through conditions
    for cond = 1 : length(conditions)

        % Loop through prefix
        for pref = 1 : length(prefix)
            try
                % Set current condition
                condition = conditions{cond};

                % Set current prefix
                cPrefix = prefix{pref};

                % Set current workingDirectory
                workingDirectory = char(fullfile(strcat(workingDirectories{wd}, pipelineName, '-', cPrefix,'\')));

                %Create error reports for each trial and save output in working directory
                disp('>>>>> Started creating error and per trial reports <<');
                createErrorReportsPerTrial(workingDirectory, rootDirectory, path2setupFiles, condition, cPrefix, trialType, processVtp);

                % Create a data report of all (selected) trials within one working
                % directory and create summarized output files and plots.
                disp('>>>>> Started creating summarized trials reports <<');
                createTrialOverview4oneSubject(workingDirectory, rootDirectory, path2setupFiles, condition, cPrefix, timeNormFlag, trialType, processVtp);

            catch ME
                if catchErrors
                    disp(char(strcat('>>>>> An error occured during processing of condition', {' "'}, condition, {'" '},'with prefix:', {' "'}, cPrefix, {'"'}, ', in wd:', {' '},  workingDirectory,{'. '}, 'Skipped prefix/condition in current wd!')));
                    fprintf('>>>>> Error message: %s\n', ME.message);
                    errN = errN + 1;
                else
                    rethrow(ME)
                end
            end
        end
    end

    % Update status in local WorkingDirectories file located in the
    % rootDirectory. Note that it is important to update and save the file
    % during each loop. In case of a Matlab crash otherwise all info
    % would be lost.

    maxAttempts = 5; % Set the maximum number of attempts
    currentAttempt = 1; % Initialize attempt counter

    while currentAttempt <= maxAttempts
        try
            wdFile = fullfile(rootDirectory, 'workingDirectories.xlsx');
            data = readtable(wdFile);
            c_idx = find(strcmp(data.WorkingDirectories, workingDirectories{wd}));
            data.Processed(c_idx) = 1;
            writetable(data, wdFile);
            break;
        catch
            % Wait for some time before the next attempt
            pause(5);

            % Increment the attempt counter
            currentAttempt = currentAttempt + 1;
        end
    end    
end

% Save errors log as *.txt in root dir. (Deprecated, does not work for parallel tool box.
% writetable(struct2table(failures), fullfile(strcat(rootDirectory,'PostProcessing-MatlabErrorLog_', replace(char(datetime), {' ',':'}, '-'),'.xlsx')));

% End timer
tEnd = toc(tStart);
disp(''); % new line
disp('********************************************************************');
disp(strcat('Total number of matlab errors catched:',{' '}, string(errN), '. <<<<<'));
fprintf('Total processing duration: %d minutes and %0.f seconds.\n', floor(tEnd/60), rem(tEnd,60));
disp('************ Post processing of all results finished ***************');