% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto
% train_pipeline.m (Training Mode Orchestrator)

clc; clear; close all;

%% Configure Paths
addpath(genpath('src'));
addpath(genpath('data'));
addpath(genpath('configs'));
addpath(genpath('models'));

disp('====================================================');
disp('      🧠 SENTINELCRYPTO TRAINING PIPELINE 🧠      ');
disp('====================================================');

%% 1 & 2. Data Ingestion & Feature Engineering
disp('-> [1-3/6] Loading Data, Sentiment, and Engineering Features...');
[fullData, X, Y] = PipelineDataProcessor.prepareData();
featureList = fullData.Properties.VariableNames(1:end-1); % Assuming Target is last
% Wait, PipelineDataProcessor uses a fixed featureList by default.
featureList = {'Open', 'High', 'Low', 'Close', 'Volume', 'SMA_20', 'SMA_50', ...
    'EMA_20', 'EMA_50', 'MACD_Line', 'MACD_Signal', 'MACD_Hist', 'RSI_14', ...
    'BB_Upper', 'BB_Lower', 'VWAP', 'Volatility_20', 'ATR_14', ...
    'Daily_Sentiment', 'Tweet_Volume'};

%% 3. Train-Test Split & Scaling (Leakage-Free)
disp('-> [4/6] Splitting Dataset & Normalizing...');
splitIdx = floor(0.8 * size(X, 1));

% 1. Split FIRST
XTrain_raw = X(1:splitIdx, :);
YTrain_raw = Y(1:splitIdx);
XTest_raw = X(splitIdx+1:end, :);
YTest_raw = Y(splitIdx+1:end);

% 2. Fit Scaler ONLY on Training Data
scaler = struct();
scaler.Min = min(XTrain_raw);
scaler.Max = max(XTrain_raw);

targetScaler = struct();
targetScaler.Min = min(YTrain_raw);
targetScaler.Max = max(YTrain_raw);

% 3. Apply Scaler to both Train and Test
XTrain = PipelineDataProcessor.scaleData(XTrain_raw, scaler);
XTest = PipelineDataProcessor.scaleData(XTest_raw, scaler);
YTrain = PipelineDataProcessor.scaleTarget(YTrain_raw, targetScaler);
YTest = PipelineDataProcessor.scaleTarget(YTest_raw, targetScaler);

%% 4. Model Training
disp('-> [5/6] Training AI Models...');

% ---- CNN-LSTM Training ----
disp('  => Training CNN-LSTM Hybrid Model...');
numFeatures = size(XTrain, 2);
layers = [
    sequenceInputLayer(numFeatures, 'Name', 'input')
    convolution1dLayer(3, 16, 'Padding', 'same', 'Name', 'conv1')
    reluLayer('Name', 'relu1')
    lstmLayer(32, 'OutputMode', 'last', 'Name', 'lstm1')
    fullyConnectedLayer(1, 'Name', 'fc')
    regressionLayer('Name', 'output')
];

options = trainingOptions('adam', ...
    'MaxEpochs', 15, ...
    'MiniBatchSize', 32, ...
    'GradientThreshold', 1, ...
    'Verbose', true, ...
    'Plots', 'none');

% Convert data for sequence input (Features x SequenceLength for each observation)
XTrainSeq = num2cell(XTrain', 1)'; 
try
    cnnLstmNet = trainNetwork(XTrainSeq, YTrain, layers, options);
    Logger.success('CNN-LSTM Training Complete.');
catch ME
    Logger.error('Deep Learning Toolbox missing or failed: %s. Creating stub model.', ME.message);
    cnnLstmNet = struct('Type', 'Stub');
end

% ---- ARIMA Training ----
disp('  => Training ARIMAX Model (using Sentiment as Exogenous Factor)...');
try
    arimaSpec = arima(1, 1, 1);
    % Find Daily_Sentiment index (19 based on featureList)
    sentimentIdx = find(strcmp(featureList, 'Daily_Sentiment'));
    if isempty(sentimentIdx)
        sentimentIdx = 19; % Fallback
    end
    
    % Extract raw sentiment data for ARIMA X factor
    sentimentTrain = XTrain_raw(:, sentimentIdx);
    
    % ARIMAX needs raw unscaled data to predict raw prices easily.
    % We pass sentiment as 'X' to satisfy MathWorks Challenge requirement #5
    arimaModel = estimate(arimaSpec, YTrain_raw, 'X', sentimentTrain, 'Display', 'off');
    Logger.success('ARIMAX Training Complete.');
catch ME
    Logger.error('Econometrics Toolbox missing or failed: %s. Creating stub model.', ME.message);
    arimaModel = struct('Type', 'Stub');
end

% ---- Random Forest Training ----
disp('  => Training Random Forest Model...');
try
    rfModel = TreeBagger(50, XTrain, YTrain, 'Method', 'regression');
    Logger.success('Random Forest Training Complete.');
catch ME
    Logger.error('Random Forest failed: %s', ME.message);
    rfModel = struct('Type', 'Stub');
end

% ---- SVM Training ----
disp('  => Training SVM Model...');
try
    svmModel = fitrsvm(XTrain, YTrain, 'Standardize', true);
    Logger.success('SVM Training Complete.');
catch ME
    Logger.error('SVM failed: %s', ME.message);
    svmModel = struct('Type', 'Stub');
end

%% 5. Model Evaluation & Leaderboard
disp('-> [5.5/6] Evaluating Models & Generating Leaderboard...');

% Helper to reverse scale predictions to raw price for accurate RMSE/MAE
revScale = @(y) y .* (targetScaler.Max - targetScaler.Min) + targetScaler.Min;

% Pre-allocate results
modelNames = {'CNN-LSTM', 'ARIMA', 'Random Forest', 'SVM'};
rmseVals = zeros(4,1);
maeVals = zeros(4,1);

% 1. CNN-LSTM
if ~strcmp(class(cnnLstmNet), 'struct')
    XTestSeq = num2cell(XTest', 1)'; 
    cnnPred = predict(cnnLstmNet, XTestSeq);
    cnnPredRaw = revScale(cnnPred);
    rmseVals(1) = sqrt(mean((YTest_raw - cnnPredRaw).^2));
    maeVals(1) = mean(abs(YTest_raw - cnnPredRaw));
else
    rmseVals(1) = NaN; maeVals(1) = NaN;
end

% 2. ARIMAX (trained on raw data, so predict outputs raw directly)
if ~strcmp(class(arimaModel), 'struct')
    sentimentIdx = find(strcmp(featureList, 'Daily_Sentiment'));
    if isempty(sentimentIdx), sentimentIdx = 19; end
    
    sentimentTrain = XTrain_raw(:, sentimentIdx);
    sentimentTest = XTest_raw(:, sentimentIdx);
    
    % forecast needs YTrain_raw as presample (Y0).
    % Since it's ARIMAX, it also needs X presample (X0) and future X values (XF)
    [arimaPred, ~] = forecast(arimaModel, length(YTest_raw), 'Y0', YTrain_raw, ...
        'X0', sentimentTrain, 'XF', sentimentTest);
        
    rmseVals(2) = sqrt(mean((YTest_raw - arimaPred).^2));
    maeVals(2) = mean(abs(YTest_raw - arimaPred));
else
    rmseVals(2) = NaN; maeVals(2) = NaN;
end

% 3. Random Forest
if ~strcmp(class(rfModel), 'struct')
    rfPred = predict(rfModel, XTest);
    rfPredRaw = revScale(rfPred);
    rmseVals(3) = sqrt(mean((YTest_raw - rfPredRaw).^2));
    maeVals(3) = mean(abs(YTest_raw - rfPredRaw));
else
    rmseVals(3) = NaN; maeVals(3) = NaN;
end

% 4. SVM
if ~strcmp(class(svmModel), 'struct')
    svmPred = predict(svmModel, XTest);
    svmPredRaw = revScale(svmPred);
    rmseVals(4) = sqrt(mean((YTest_raw - svmPredRaw).^2));
    maeVals(4) = mean(abs(YTest_raw - svmPredRaw));
else
    rmseVals(4) = NaN; maeVals(4) = NaN;
end

% Generate Model Leaderboard HTML
reportsDir = fullfile(pwd, 'reports');
if ~exist(reportsDir, 'dir'), mkdir(reportsDir); end
htmlPath = fullfile(reportsDir, 'ModelLeaderboard.html');

fid = fopen(htmlPath, 'w');
fprintf(fid, '<!DOCTYPE html><html><head><title>Model Leaderboard</title>');
fprintf(fid, '<style>body{font-family:Arial,sans-serif;margin:40px;background-color:#f9f9f9;} ');
fprintf(fid, 'h1{color:#333;} table{border-collapse:collapse;width:80%%;margin-top:20px;background-color:#fff;} ');
fprintf(fid, 'th,td{border:1px solid #ddd;padding:12px;text-align:left;} th{background-color:#0072BD;color:white;} ');
fprintf(fid, 'tr:nth-child(even){background-color:#f2f2f2;} .best{font-weight:bold;color:#d9534f;}</style></head><body>');
fprintf(fid, '<h1>🏆 SentinelCrypto Model Leaderboard 🏆</h1>');
fprintf(fid, '<p>Evaluation on Hold-Out Test Set (Raw USD Prices)</p>');
fprintf(fid, '<table><tr><th>Rank</th><th>Model</th><th>RMSE ($)</th><th>MAE ($)</th></tr>');

% Sort models by RMSE
validIdx = ~isnan(rmseVals);
validRmse = rmseVals(validIdx);
validMae = maeVals(validIdx);
validNames = modelNames(validIdx);
[~, sortIdx] = sort(validRmse);

for i = 1:length(sortIdx)
    idx = sortIdx(i);
    rowClass = '';
    if i == 1, rowClass = ' class="best"'; end
    fprintf(fid, '<tr%s><td>%d</td><td>%s</td><td>%.2f</td><td>%.2f</td></tr>', ...
        rowClass, i, validNames{idx}, validRmse(idx), validMae(idx));
end
fprintf(fid, '</table><p><i>Generated on: %s</i></p></body></html>', datestr(now));
fclose(fid);
Logger.success('Model Leaderboard generated at reports/ModelLeaderboard.html');

% ---- Ensemble Calculation ----
% Equal weighting for demo structure; in practice, use a meta-learner like XGBoost
ensembleWeights = [0.6, 0.4]; % CNN-LSTM, ARIMA (or use the best models)

%% 6. Model Saving
disp('-> [6/6] Saving Artifacts to disk...');
mgr = ModelManager();
mgr.saveArtifacts(cnnLstmNet, [], arimaModel, ensembleWeights, scaler, targetScaler, featureList);

disp('====================================================');
disp('   ✅ TRAINING PIPELINE COMPLETE ✅    ');
disp('   Models are now available for Live Prediction.    ');
disp('====================================================');
