%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
% generate_sample_data.m
% Generates small sample datasets for MathWorks Challenge evaluators.
% Creates a 500-row slice of BTC price data and a 100-row slice of tweets.

clc; clear;

% Define the root directory relatively
rootDir = pwd;
sampleDir = fullfile(rootDir, 'data', 'sample');

if ~exist(sampleDir, 'dir')
    mkdir(sampleDir);
end

disp('======================================================');
disp('   Generating MathWorks Challenge Sample Datasets     ');
disp('======================================================');

% 1. Create sample price data
btcFile = fullfile(rootDir, 'btc.csv');
btcSampleFile = fullfile(sampleDir, 'btc_sample.csv');

if exist(btcFile, 'file')
    opts = detectImportOptions(btcFile);
    opts.DataLines = [2, 501]; % Read first 500 rows
    try
        T = readtable(btcFile, opts);
        writetable(T, btcSampleFile);
        disp(['✅ Created ', btcSampleFile, ' (', num2str(height(T)), ' rows)']);
    catch ME
        warning('Failed to create BTC sample: %s', ME.message);
    end
end

% 2. Create sample tweet data
% The full dataset is 2GB, reading even a part using readtable can be slow.
% We will use low-level text read for the first 100 lines.
tweetFile = fullfile(rootDir, 'Bitcoin_tweets.csv');
tweetSampleFile = fullfile(sampleDir, 'Bitcoin_tweets_sample.csv');

if exist(tweetFile, 'file')
    try
        fidIn = fopen(tweetFile, 'r', 'n', 'UTF-8');
        fidOut = fopen(tweetSampleFile, 'w', 'n', 'UTF-8');
        
        for i = 1:500
            line = fgetl(fidIn);
            if ischar(line)
                fprintf(fidOut, '%s\n', line);
            else
                break;
            end
        end
        
        fclose(fidIn);
        fclose(fidOut);
        disp(['✅ Created ', tweetSampleFile, ' (500 lines)']);
    catch ME
        warning('Failed to create Tweets sample: %s', ME.message);
    end
end

disp('Done generating sample data!');
