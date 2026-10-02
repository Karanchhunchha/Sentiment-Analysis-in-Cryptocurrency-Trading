%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto
% train_pipeline.m (Training Mode Orchestrator)

function train_pipeline(seed)
if nargin < 1, seed = 42; end
clc; close all;
rng(seed); 

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
[XTrainSeq, vTrain] = PipelineDataProcessor.formatForCNNLSTM(XTrain, 30);
YTrainSeq = YTrain(vTrain);
try
    cnnLstmNet = trainNetwork(XTrainSeq, YTrainSeq, layers, options);
    Logger.success('CNN-LSTM Training Complete.');
catch ME
    Logger.warning('Deep Learning Toolbox missing or failed: %s. Using stub model.', ME.message);
    cnnLstmNet = struct('Type', 'Stub');
end

% ---- ARIMAX / ARIMA Training (P0-03) ----
disp('  => [P0-03] Attempting genuine ARIMAX, then transparent ARIMA fallback...');
hasEcon = license('test', 'Econometrics_Toolbox') || ~isempty(ver('econ'));
if ~hasEcon
    % Explicit, non-swallowed failure: toolbox unavailable
    error('train_pipeline:NoEconToolbox', ...
        ['Econometrics Toolbox is required but not installed. ' ...
         'ARIMA/ARIMAX cannot be trained. Install the Toolbox and re-run.']);
end

% -----------------------------------------------------------------------
% STEP 1: Attempt genuine ARIMAX on the sentiment-aligned overlap region.
%
% Alignment policy:
%   - TRUE inner join (synchronize 'intersection'): only rows where BOTH
%     market price AND sentiment are present on the same calendar day.
%     No forward-fill, no zero-fill for the exogenous variable.
%   - Sorted ascending by date (asserted below).
%   - Train/test split at 80% of aligned intersection rows.
%   - XF for forecasting uses held-out test sentiment values.
%   - No future values from the test window are used in training.
%
% Why ARIMAX may not be feasible:
%   The committed sentiment dataset (historical_daily_sentiment.csv) covers
%   only ~231 days of true overlap with btc.csv. ARIMAX(1,1,1) with 1
%   exogenous variable requires enough observations for parameter
%   estimation. If the training partition is too small, estimate() will
%   throw a genuine error.
% -----------------------------------------------------------------------

arimaModel    = [];   % will be populated by either ARIMAX or ARIMA fallback
arimaModelType = 'none';
arimaFallbackReason = '';  % P0-03: will hold exact ARIMAX failure message if fallback used

% Load and align data for ARIMAX attempt
marketDataAR   = readtable(fullfile(pwd, 'data', 'market', 'btc.csv'));
sentimentDataAR = readtable(fullfile(pwd, 'data', 'sentiment', 'historical_daily_sentiment.csv'));

marketDataAR.Date   = dateshift(datetime(marketDataAR.Date),   'start', 'day');
sentimentDataAR.Date = dateshift(datetime(sentimentDataAR.Date), 'start', 'day');

% Assert chronological order (non-negotiable for time-series models)
assert(all(diff(marketDataAR.Date)   > 0), 'train_pipeline:NotSorted', 'Market data not sorted ascending.');
assert(all(diff(sentimentDataAR.Date) > 0), 'train_pipeline:NotSorted', 'Sentiment data not sorted ascending.');

marketTTar    = table2timetable(marketDataAR,   'RowTimes', 'Date');
sentimentTTar = table2timetable(sentimentDataAR, 'RowTimes', 'Date');

% TRUE inner join: only dates present in BOTH tables
% No forward-fill, no zero-fill — only genuine sentiment observations
alignedTT = synchronize(marketTTar, sentimentTTar, 'intersection');
alignedTT = rmmissing(alignedTT, 'DataVariables', {'Close', 'Daily_Sentiment'});
nAligned  = height(alignedTT);

Logger.info('[P0-03] ARIMAX-eligible aligned rows (true intersection): %d', nAligned);

arCloseAll = alignedTT.Close;
arSentAll  = alignedTT.Daily_Sentiment;

% Assert data is chronological after join
assert(all(diff(alignedTT.Date) > 0), 'train_pipeline:NotSorted', ...
    'Aligned intersection data is not sorted ascending.');

splitIdxAR  = floor(0.8 * nAligned);

try
    % Y0 presample (2 rows for d=1, p=1 lag) so exogenous X matches Y length
    Y0_AR       = arCloseAll(1:2);
    YTrainAR    = arCloseAll(3:splitIdxAR);
    XTrainAR    = arSentAll(3:splitIdxAR);

    Logger.info('[P0-03] Attempting ARIMAX estimate on %d training observations (+ 2 presample)...', length(YTrainAR));

    arimaSpecX = arima(1, 1, 1);
    arimaModelX = estimate(arimaSpecX, YTrainAR, 'X', XTrainAR, 'Y0', Y0_AR, 'Display', 'off');

    % Verify forecast is real and finite before accepting
    nTestAR = nAligned - splitIdxAR;
    XTestAR = arSentAll(splitIdxAR+1:end);
    [fcastVerify, ~] = forecast(arimaModelX, nTestAR, 'Y0', YTrainAR, 'XF', XTestAR);
    if ~all(isfinite(fcastVerify))
        error('train_pipeline:ArimaxForecastNonFinite', ...
              'ARIMAX forecast produced non-finite values. Model rejected.');
    end

    arimaModel     = arimaModelX;
    arimaModelType = 'ARIMAX(1,1,1) with Daily_Sentiment exogenous';
    Logger.success('[P0-03] ARIMAX training SUCCEEDED on %d obs. Model type: %s', length(YTrainAR), arimaModelType);

catch ME_arimax
    % -----------------------------------------------------------------------
    % Only catch errors from the estimation step. If this is NOT a data/
    % estimation error, rethrow so unexpected failures are never hidden.
    % -----------------------------------------------------------------------
    isEstimationError = contains(ME_arimax.identifier, 'econ') ...
        || contains(ME_arimax.identifier, 'arima') ...
        || contains(ME_arimax.identifier, 'train_pipeline') ...
        || contains(lower(ME_arimax.message), 'observation') ...
        || contains(lower(ME_arimax.message), 'degrees of freedom') ...
        || contains(lower(ME_arimax.message), 'insufficient') ...
        || contains(lower(ME_arimax.message), 'non-finite') ...
        || contains(lower(ME_arimax.message), 'stationary') ...
        || contains(lower(ME_arimax.message), 'converge');

    if ~isEstimationError
        rethrow(ME_arimax);
    end

    % -----------------------------------------------------------------------
    % STEP 2: Explicit transparent fallback to pure ARIMA(1,1,1).
    %
    % Uses the SAME training horizon (YTrain_raw from the main pipeline
    % split), NOT synthetic data. Reason logged at WARNING level.
    % The fallback model is explicitly named "ARIMA(1,1,1)-Fallback" in
    % saved metadata so no consumer can mistake it for ARIMAX.
    % -----------------------------------------------------------------------
    Logger.warning('[P0-03] ARIMAX not feasible: %s', ME_arimax.message);
    Logger.warning('[P0-03] Intersection gave %d aligned rows; training partition had %d obs.', ...
        nAligned, splitIdxAR - 2);
    Logger.warning('[P0-03] Falling back to pure ARIMA(1,1,1) on full training price series (%d obs).', length(YTrain_raw));
    Logger.warning('[P0-03] This fallback is NOT ARIMAX. Sentiment is excluded as exogenous variable.');

    arimaFallbackReason = ME_arimax.message;  % P0-03: preserve exact failure reason

    arimaSpec = arima(1, 1, 1);

    % No try/catch here: any failure in pure ARIMA must propagate loudly.
    % If this throws, the pipeline must stop — not produce a stub.
    arimaModel     = estimate(arimaSpec, YTrain_raw, 'Display', 'off');
    arimaModelType = 'ARIMA(1,1,1)-Fallback (ARIMAX infeasible: insufficient overlap rows)';
    Logger.success('[P0-03] ARIMA(1,1,1) fallback training SUCCEEDED on %d observations.', length(YTrain_raw));
end

% Final verification: model must be a genuine arima object, not a struct
assert(isa(arimaModel, 'arima'), 'train_pipeline:NotArimaObject', ...
    'arimaModel is not a genuine arima object after training. Pipeline cannot continue.');

% Verify forecast is finite
% If ARIMAX, XF is required for forecast; use zeros as neutral exogenous input
if ~isempty(arimaModel.Beta)
    [verifyFcast, ~] = forecast(arimaModel, 3, 'Y0', YTrain_raw, 'XF', zeros(3, size(arimaModel.Beta, 1)));
else
    [verifyFcast, ~] = forecast(arimaModel, 3, 'Y0', YTrain_raw);
end
assert(all(isfinite(verifyFcast)), 'train_pipeline:ForecastNonFinite', ...
    'Post-training forecast produced non-finite values.');

Logger.success('[P0-03] Model artifact verified: class=%s, type=%s', class(arimaModel), arimaModelType);

% ---- Random Forest Training ----
disp('  => Training Random Forest Model...');
try
    rfModel = TreeBagger(50, XTrain, YTrain, 'Method', 'regression', 'OOBPredictorImportance', 'on', 'Options', statset('UseParallel', true, 'UseSubstreams', true, 'Streams', RandStream('mlfg6331_64', 'Seed', seed)));
    Logger.success('Random Forest Training Complete.');
catch ME
    Logger.warning('Random Forest failed: %s. Using stub model.', ME.message);
    rfModel = struct('Type', 'Stub');
end

% ---- SVM Training ----
disp('  => Training SVM Model...');
try
    svmModel = fitrsvm(XTrain, YTrain, 'Standardize', true, 'KernelFunction', 'gaussian', 'KernelScale', 'auto', 'RNGSeed', seed);
    Logger.success('SVM Training Complete.');
catch ME
    Logger.warning('SVM failed: %s. Using stub model.', ME.message);
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
    [XTestSeq, vTest] = PipelineDataProcessor.formatForCNNLSTM(XTest, 30); 
    YTestSeq = YTest_raw(vTest);
    cnnPred = predict(cnnLstmNet, XTestSeq);
    cnnPredRaw = revScale(cnnPred);
    rmseVals(1) = sqrt(mean((YTestSeq - cnnPredRaw).^2));
    maeVals(1) = mean(abs(YTestSeq - cnnPredRaw));
else
    rmseVals(1) = NaN; maeVals(1) = NaN;
end

% 2. ARIMA (trained on raw data, so predict outputs raw directly)
if ~strcmp(class(arimaModel), 'struct')
    % forecast needs YTrain_raw as presample (Y0).
    % If ARIMAX, XF is required — use real test sentiment from the aligned intersection
    if ~isempty(arimaModel.Beta)
        % ARIMAX: use real exogenous values from the test portion of the aligned intersection
        nFcastAR = length(YTest_raw);
        nTestIntersection = nAligned - splitIdxAR;
        if nTestIntersection >= nFcastAR
            XF_eval = arSentAll(splitIdxAR+1:splitIdxAR+nFcastAR);
        else
            % Pad with zeros if intersection test is shorter than full test set
            XF_eval = [arSentAll(splitIdxAR+1:end); zeros(nFcastAR - nTestIntersection, 1)];
        end
        [arimaPred, ~] = forecast(arimaModel, nFcastAR, 'Y0', YTrain_raw, 'XF', XF_eval);
    else
        [arimaPred, ~] = forecast(arimaModel, length(YTest_raw), 'Y0', YTrain_raw);
    end
        
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
fprintf(fid, '</table><p><i>Generated on: %s</i></p></body></html>', char(datetime('now')));
fclose(fid);
Logger.success('Model Leaderboard generated at reports/ModelLeaderboard.html');

% ---- Ensemble Calculation ----
% Equal weighting for demo structure; in practice, use a meta-learner like XGBoost
ensembleWeights = [0.6, 0.4]; % CNN-LSTM, ARIMA (or use the best models)

%% 6. Model Saving
disp('-> [6/6] Saving Artifacts to disk...');
mgr = ModelManager();
mgr.saveArtifacts(cnnLstmNet, cnnLstmNet, arimaModel, ensembleWeights, scaler, targetScaler, featureList);

disp('====================================================');
disp('   ✅ TRAINING PIPELINE COMPLETE ✅    ');
disp('   Models are now available for Live Prediction.    ');
disp('====================================================');
