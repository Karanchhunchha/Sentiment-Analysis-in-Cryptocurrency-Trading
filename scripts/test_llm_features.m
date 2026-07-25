% scripts/test_llm_features.m
% Task 2: Pushes real sample records through LLMFeatureExtractor, logging traces/exceptions.

clc;
clear;

disp('======================================================');
disp('      Task 2: LLM Feature Extractor Live Verification ');
disp('======================================================');

% Dynamic root directory detection
scriptPath = mfilename('fullpath');
[scriptDir, ~, ~] = fileparts(scriptPath);
[rootDir, ~, ~] = fileparts(scriptDir);

addpath(genpath(fullfile(rootDir, 'src')));

% 1. Create evidence directory
evidenceDir = fullfile(rootDir, 'evidence');
if ~exist(evidenceDir, 'dir')
    mkdir(evidenceDir);
end
logFile = fullfile(evidenceDir, 'llm_feature_test_log.txt');
fidLog = fopen(logFile, 'w');
if fidLog == -1
    error('Could not create log file: %s', logFile);
end

fprintf(fidLog, '--- LLM FEATURE EXTRACTOR VERIFICATION LOG ---\n');
fprintf(fidLog, 'Timestamp: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

% 2. Load 25 sample tweets from prepared data
sampleFile = fullfile(rootDir, 'data', 'sample', 'Bitcoin_tweets_sample.csv');
disp(['Loading sample tweets from: ', sampleFile]);
fprintf(fidLog, 'Loading sample tweets from: %s\n', sampleFile);

try
    opts = detectImportOptions(sampleFile);
    opts.SelectedVariableNames = {'text'};
    opts.DataLines = [2, 26]; % Load 25 records (rows 2 to 26)
    T = readtable(sampleFile, opts);
    sampleTexts = T.text;
    disp('✅ Loaded 25 sample tweets successfully.');
    fprintf(fidLog, '✅ Loaded %d sample tweets.\n', numel(sampleTexts));
catch ME
    fprintf('Failed to load sample tweets: %s\n', ME.message);
    fprintf(fidLog, '❌ Failed to load sample tweets: %s\n', ME.message);
    fclose(fidLog);
    rethrow(ME);
end

% 3. Run LLM Extraction and catch exceptions explicitly
try
    disp('Attempting to instantiate LLMFeatureExtractor...');
    fprintf(fidLog, 'Instantiating LLMFeatureExtractor...\n');
    
    extractor = LLMFeatureExtractor();
    
    disp('Sending samples to LLM...');
    fprintf(fidLog, 'Piping samples to LLM...\n');
    
    for i = 1:numel(sampleTexts)
        txt = sampleTexts{i};
        fprintf('Processing Tweet #%d: "%s"\n', i, txt);
        fprintf(fidLog, 'Input Tweet #%d: "%s"\n', i, txt);
        
        score = extractor.extractFeaturesFromText({txt});
        
        fprintf('Resulting Score: %.4f\n', score);
        fprintf(fidLog, 'Result Score: %.4f\n', score);
    end
    
    disp('✅ LLM Extraction Completed successfully.');
    fprintf(fidLog, '✅ LLM Extraction Completed successfully.\n');
    
catch ME
    % Print failure explicitly in cmd window
    fprintf('\n[CRITICAL ERROR DURING LLM EXTRACTION]\n');
    fprintf('Identifier: %s\n', ME.identifier);
    fprintf('Message: %s\n', ME.message);
    
    % Pipe exception details directly to log
    fprintf(fidLog, '\n❌ CRITICAL ERROR ENCOUNTERED during LLM processing:\n');
    fprintf(fidLog, 'Identifier: %s\n', ME.identifier);
    fprintf(fidLog, 'Message: %s\n', ME.message);
    
    % Traceback print
    if ~isempty(ME.stack)
        fprintf(fidLog, 'Stack trace:\n');
        for s = 1:numel(ME.stack)
            fprintf(fidLog, '  in %s at line %d (%s)\n', ...
                ME.stack(s).name, ME.stack(s).line, ME.stack(s).file);
        end
    end
end

fclose(fidLog);
disp(['Task 2 Complete. Logs written to ', logFile]);
