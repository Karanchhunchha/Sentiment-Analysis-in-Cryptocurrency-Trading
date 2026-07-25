% scripts/prepare_tweet_data.m
% Task 1: Prepares raw tweet datasets, validates columns, and maps them with Binance history.

clc;
clear;

disp('======================================================');
disp('   Task 1: Tweet Data Preparation & Validation   ');
disp('======================================================');

% Determine the root directory dynamically relative to the script path
scriptPath = mfilename('fullpath');
[scriptDir, ~, ~] = fileparts(scriptPath);
[rootDir, ~, ~] = fileparts(scriptDir);
sentimentDir = fullfile(rootDir, 'data', 'sentiment');
marketDir = fullfile(rootDir, 'data', 'market');

% 1. Verify source datasets exist in data/sentiment/
tweetsFile1 = fullfile(sentimentDir, 'Bitcoin_tweets.csv');
tweetsFile2 = fullfile(sentimentDir, 'Bitcoin_tweets_dataset_2.csv');

if ~exist(tweetsFile1, 'file')
    error('Missing dataset: %s. Please make sure the Kaggle dataset is downloaded to data/sentiment/.', tweetsFile1);
end
if ~exist(tweetsFile2, 'file')
    error('Missing dataset: %s. Please make sure the Kaggle dataset is downloaded to data/sentiment/.', tweetsFile2);
end

disp('✅ Found Kaggle datasets in data/sentiment/');

% 2. Check if we need to link/copy them to the root directory for SentimentEngine
targetFile1 = fullfile(rootDir, 'Bitcoin_tweets.csv');
targetFile2 = fullfile(rootDir, 'Bitcoin_tweets_dataset_2.csv');

if ~exist(targetFile1, 'file')
    disp('Creating symlink/copy for Bitcoin_tweets.csv in root...');
    % Try symlinking first (fastest, saves 2GB disk space)
    [status, cmdout] = system(sprintf('cmd /c mklink "%s" "%s"', targetFile1, tweetsFile1));
    if status ~= 0
        disp('Symlink failed (requires admin rights). Copying file instead...');
        copyfile(tweetsFile1, targetFile1);
        disp('✅ Copied Bitcoin_tweets.csv to root.');
    else
        disp('✅ Symlinked Bitcoin_tweets.csv to root.');
    end
else
    disp('✅ Bitcoin_tweets.csv is already in root.');
end

if ~exist(targetFile2, 'file')
    disp('Creating symlink/copy for Bitcoin_tweets_dataset_2.csv in root...');
    [status, cmdout] = system(sprintf('cmd /c mklink "%s" "%s"', targetFile2, tweetsFile2));
    if status ~= 0
        disp('Symlink failed (requires admin rights). Copying file instead...');
        copyfile(tweetsFile2, targetFile2);
        disp('✅ Copied Bitcoin_tweets_dataset_2.csv to root.');
    else
        disp('✅ Symlinked Bitcoin_tweets_dataset_2.csv to root.');
    end
else
    disp('✅ Bitcoin_tweets_dataset_2.csv is already in root.');
end

% 3. Format/Validate Column Names & Structures
disp('Verifying column names...');
fid = fopen(targetFile2, 'r', 'n', 'UTF-8');
if fid == -1
    error('Failed to open %s', targetFile2);
end
headerLine = fgetl(fid);
fclose(fid);

headers = split(string(headerLine), ',');
disp('Detected CSV Headers:');
disp(headers');

dateIdx = find(headers == "date", 1);
textIdx = find(headers == "text", 1);

if isempty(dateIdx) || isempty(textIdx)
    error('Dataset format invalid. Missing precisely "date" or "text" columns.');
else
    disp('✅ Confirmed precisely formatted columns: "date" and "text".');
end

% 4. Run Sentiment Engine process on a small portion or whole dataset
disp('Running SentimentEngine to generate historical daily sentiment scores...');
addpath(genpath(fullfile(rootDir, 'src')));

% Temporarily switch MATLAB current directory to rootDir so SentimentEngine resolves paths relative to project root
origDir = pwd;
cd(rootDir);
cleanupDir = onCleanup(@() cd(origDir));

try
    engine = SentimentEngine();
    dailySentiment = engine.processHistoricalTweets();
    disp('✅ Successfully generated daily sentiment scores.');
    disp(head(dailySentiment));
catch ME
    fprintf('Error during sentiment calculation: %s\n', ME.message);
    rethrow(ME);
end

% 5. Map with Binance crypto history
disp('Mapping sentiment dataset with Binance crypto price history...');
loader = PriceDataLoader('BTCUSDT', '1d');
btcFile = fullfile(marketDir, 'btc.csv');

try
    marketData = loader.loadHistoricalCSV(btcFile);
    marketData.Date = dateshift(datetime(marketData.Date), 'start', 'day');
    dailySentiment.Date = dateshift(datetime(dailySentiment.Date), 'start', 'day');
    
    % Merge/inner join
    fullData = innerjoin(marketData, dailySentiment, 'Keys', 'Date');
    disp('✅ Successfully mapped and aligned tweet sentiment with Binance price history.');
    disp(head(fullData));
    
    % Show output matrix sizing
    fprintf('Final combined matrix height: %d rows.\n', height(fullData));
catch ME
    fprintf('Error during mapping/alignment: %s\n', ME.message);
    rethrow(ME);
end

disp('=== TASK 1 COMPLETE ===');
