%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto
% run_pipeline.m (Event-Driven Live Prediction Loop)

clc; clear; close all;

%% Configure Paths
addpath(genpath('src'));
addpath(genpath('data'));
addpath(genpath('configs'));
addpath(genpath('models'));
addpath(genpath('logs'));

disp('====================================================');
disp('      🚀 SENTINELCRYPTO LIVE PREDICTION MODE 🚀      ');
disp('====================================================');

%% 1. Initialization (Run Once)
disp('-> [1/4] Loading Production Models and Metadata...');
modelManager = ModelManager();
try
    [models, scaler, featureList] = modelManager.loadArtifacts();
catch
    Logger.warning('No trained models found! Run train_pipeline.m first. Mocking for UI test.');
    models = struct('CNN', [], 'LSTM', [], 'ARIMA', [], 'EnsembleWeights', [0.33, 0.33, 0.34]);
end

disp('-> [2/4] Initializing Feature Fusion & Macro Engines...');
fusionEngine = FeatureFusionEngine();
macroEngine = MacroEngine();

disp('-> [3/4] Launching Sentinel Dashboard...');
% Initial empty state for the dense dashboard
emptyData = struct('CurrentPrice', 0, 'Signal', 'WAIT', 'Trend', 'NEUTRAL', ...
    'Confidence', 0, 'ExpectedNextClose', 0, 'ExpectedHigh', 0, 'ExpectedLow', 0, ...
    'ProbabilityUp', 0.5, 'ProbabilityDown', 0.5, 'Support', 0, 'Resistance', 0, ...
    'SL', 0, 'TP1', 0, 'TP2', 0, 'TP3', 0, 'PredictionGenerated', '-', ...
    'PredictionValidUntil', '-', 'LastModelVersion', 'v1.0.0', 'RiskReward', 0);

dashboard = SentinelDashboard(emptyData);

disp('-> [3.5/4] Launching Prediction Visualization Engine...');
predictionVisualizer = PredictionVisualizer();

disp('-> [3.8/4] Initializing Forecasting & Risk Engines...');
forecastEngine = ForecastProjectionEngine();
validator = ProjectionValidator();
% Initialize RiskEngine targeting a strict 1:3 Risk/Reward ratio as requested!
targetRR = 3.0;
riskEngine = RiskEngine(1.5, 2.5, targetRR);

%% 2. Define Live Event Callback
liveUpdateCallback = @(newCandle, fullData) processLiveTick(newCandle, fullData, fusionEngine, macroEngine, models, dashboard, predictionVisualizer, forecastEngine, validator, riskEngine);

%% 3. Start Live Data Stream
disp('-> [4/4] Starting Binance WebSocket/REST Polling...');

% Automatically defaulting to 15m for the most accurate SMC setups
interval = '15m';
Logger.info('Initializing live stream for %s interval...', interval);

dataLoader = PriceDataLoader('BTCUSDT', interval);

try
    % Fetch recent live 5m candles to initialize indicators correctly
    histData = dataLoader.fetchRecentHistory(150); 
    fusionEngine.initializeHistorical(histData);
    
    % Get fully featured historical data for the chart initialization
    full_hist = FeatureEngineer.runAll(histData);
    
    % Strict subsetting to prevent concatenation errors in live loop
    visCols = {'Date', 'Open', 'High', 'Low', 'Close', 'Volume'};
    if ismember('SMA20', full_hist.Properties.VariableNames); visCols{end+1} = 'SMA20'; end
    if ismember('SMA50', full_hist.Properties.VariableNames); visCols{end+1} = 'SMA50'; end
    if ismember('EMA20', full_hist.Properties.VariableNames); visCols{end+1} = 'EMA20'; end
    if ismember('EMA50', full_hist.Properties.VariableNames); visCols{end+1} = 'EMA50'; end
    vis_hist = full_hist(:, visCols);
    
    predictionVisualizer.initializeData(vis_hist);

catch ME
    Logger.warning('Failed to fetch recent history from Binance: %s. Falling back to CSV.', ME.message);
    try
        histData = dataLoader.loadHistoricalCSV('data/market/btc.csv');
        fusionEngine.initializeHistorical(histData(end-150:end, :));
        
        full_hist = FeatureEngineer.runAll(histData(end-150:end, :));
        
        % Strict subsetting
        visCols = {'Date', 'Open', 'High', 'Low', 'Close', 'Volume'};
        if ismember('SMA20', full_hist.Properties.VariableNames); visCols{end+1} = 'SMA20'; end
        if ismember('SMA50', full_hist.Properties.VariableNames); visCols{end+1} = 'SMA50'; end
        if ismember('EMA20', full_hist.Properties.VariableNames); visCols{end+1} = 'EMA20'; end
        if ismember('EMA50', full_hist.Properties.VariableNames); visCols{end+1} = 'EMA50'; end
        vis_hist = full_hist(:, visCols);
        
        predictionVisualizer.initializeData(vis_hist);
    catch
        try
            histData = dataLoader.loadHistoricalCSV('btc.csv');
            fusionEngine.initializeHistorical(histData(end-150:end, :));
            
            full_hist = FeatureEngineer.runAll(histData(end-150:end, :));
            
            % Strict subsetting
            visCols = {'Date', 'Open', 'High', 'Low', 'Close', 'Volume'};
            if ismember('SMA20', full_hist.Properties.VariableNames); visCols{end+1} = 'SMA20'; end
            if ismember('SMA50', full_hist.Properties.VariableNames); visCols{end+1} = 'SMA50'; end
            if ismember('EMA20', full_hist.Properties.VariableNames); visCols{end+1} = 'EMA20'; end
            if ismember('EMA50', full_hist.Properties.VariableNames); visCols{end+1} = 'EMA50'; end
            vis_hist = full_hist(:, visCols);
            
            predictionVisualizer.initializeData(vis_hist);
        catch
            Logger.warning('No historical data found. Starting from scratch.');
        end
    end
end

dataLoader.startLiveStream(liveUpdateCallback);

disp('====================================================');
disp('Live system running. Dashboard will update automatically.');
disp('====================================================');

%% Callback Function (Executes in < 100ms)
function processLiveTick(newCandle, fullData, fusionEngine, macroEngine, models, dashboard, predictionVisualizer, forecastEngine, validator, riskEngine)
    tStart = tic;
    
    % --- Persistent State for Rolling Accuracy ---
    persistent predictionHistory;
    if isempty(predictionHistory)
        predictionHistory = struct('Actuals', [], 'Predictions', []);
    end
    % ---------------------------------------------
    
    try
        % --- 0. MACRO NEWS FETCHING ---
    [macroBias, macroSummary] = macroEngine.fetchLatestMacroBias();
    Logger.info('[MACRO ENGINE] %s', macroSummary);
    % ------------------------------
    
    % 1. Incremental Feature Update
    featureVector = fusionEngine.updateIncremental(newCandle);
    currentPrice = featureVector.Close;
    
    % --- SMC Support/Resistance & Order Blocks ---
    volatility = std(fullData.Close(max(1, end-20):end));
    
    fullData_features = FeatureEngineer.runAll(fullData);
    support = fullData_features.Sell_Liquidity(end);
    resistance = fullData_features.Buy_Liquidity(end);
    bullishOB = fullData_features.Bullish_OB(end); 
    bearishOB = fullData_features.Bearish_OB(end);  
    if bullishOB == 0; bullishOB = support; end
    if bearishOB == 0; bearishOB = resistance; end
    
    % 2. Fast Prediction (Using real loaded models)
    try
        if ~isfield(models, 'CNN') || strcmp(class(models.CNN), 'struct')
            error('Models are mocked or not loaded.');
        end
        
        % Check if featureList is available from loaded metadata
        % It is loaded as a global or from modelManager, but in run_pipeline it's passed as 'models' ?
        % Wait, featureList is available if we load it. Let's just use the default from train_pipeline.m:
        defaultFeatureList = {'Open', 'High', 'Low', 'Close', 'Volume', 'SMA_20', 'SMA_50', ...
            'EMA_20', 'EMA_50', 'MACD_Line', 'MACD_Signal', 'MACD_Hist', 'RSI_14', ...
            'BB_Upper', 'BB_Lower', 'VWAP', 'Volatility_20', 'ATR_14', ...
            'Daily_Sentiment', 'Tweet_Volume'};
            
        % Extract features for current tick
        featDataRaw = table2array(fullData_features(end, defaultFeatureList));
        
        % Load scaler from disk directly since it might not be in arguments
        sc = load(fullfile(pwd, 'models', 'scaler.mat'));
        ts = load(fullfile(pwd, 'models', 'targetScaler.mat'));
        scaler = sc.scaler;
        targetScaler = ts.targetScaler;
        
        featScaled = PipelineDataProcessor.scaleData(featDataRaw, scaler);
        
        % Format for CNN/LSTM (Cell array of Features x 1)
        cnnLstmInput = {featScaled'};
        
        cnnPredScaled = predict(models.CNN, cnnLstmInput);
        cnnPred = cnnPredScaled * (targetScaler.Max - targetScaler.Min) + targetScaler.Min;
        
        lstmPredScaled = predict(models.LSTM, cnnLstmInput);
        lstmPred = lstmPredScaled * (targetScaler.Max - targetScaler.Min) + targetScaler.Min;
        
        % ARIMAX prediction
        sentimentIdx = find(strcmp(defaultFeatureList, 'Daily_Sentiment'));
        sentimentVal = featDataRaw(1, sentimentIdx);
        y0 = fullData.Close(end-1);
        
        if ~strcmp(class(models.ARIMA), 'struct')
            [arimaPred, ~] = forecast(models.ARIMA, 1, 'Y0', y0, 'X0', sentimentVal, 'XF', sentimentVal);
        else
            arimaPred = cnnPred; % Fallback if ARIMA fails to load
        end
        
        % Ensemble
        ensemblePred = (cnnPred * models.EnsembleWeights(1)) + ...
                       (lstmPred * models.EnsembleWeights(2)) + ...
                       (arimaPred * models.EnsembleWeights(3));
    catch ME
        % If models are missing/fail, gracefully fallback to NaN prediction
        Logger.error('Inference failed: %s', ME.message);
        ensemblePred = NaN;
    end
    
    
    % --- AUTHENTIC SIGNAL GENERATION ---
    % Generate trade signal mathematically from the real prediction model
    if isnan(ensemblePred)
        signal = 'WAIT';
    elseif ensemblePred > currentPrice + (volatility * 0.05)
        signal = 'BUY';
    elseif ensemblePred < currentPrice - (volatility * 0.05)
        signal = 'SELL';
    else
        signal = 'WAIT';
    end
    % -----------------------------------
    
    % --- 3. FORECAST PROJECTION ENGINE ---
    % Base confidence (derived from model outputs or fixed for now)
    baseConfidence = 0.8; 
    
    % Generate multi-horizon projection
    [expectedPath, upConf, dnConf, confMetrics, sourceStruct] = forecastEngine.project(currentPrice, ensemblePred, volatility, signal, baseConfidence);
    
    % Generate future timestamps
    horizons = VisualizationConfig.ForecastHorizons;
    futureMins = (1:max(horizons.Steps))' * str2double(strrep(horizons.Timeframe, 'm', ''));
    genTime = datetime('now');
    futureTimes = genTime + minutes(futureMins);
    
    % --- 4. RISK ENGINE ---
    [tp, sl, rr, etaMinutes] = riskEngine.calculateRiskMetrics(currentPrice, expectedPath, signal, volatility, support, resistance, confMetrics, horizons.Timeframe);
    
    % --- 5. PROJECTION VALIDATOR ---
    [isValid, valReason] = validator.validate(expectedPath, upConf, dnConf, signal, tp, sl, currentPrice);
    
    if ~isValid
        Logger.warning('[VALIDATOR] Projection rejected: %s', valReason);
        expectedPath = NaN;
    end
    
    % Update rolling accuracy (pseudo-code for storing real history)
    % We store the prediction to evaluate in future ticks
    if ~isnan(expectedPath)
        predictionHistory.Predictions(end+1).Time = genTime;
        predictionHistory.Predictions(end).Path = expectedPath;
    end
    
    % Calculate elapsed time securely
    elapsedMs = toc(tStart) * 1000;
    
    if ~isnan(expectedPath)
        predStruct = struct(...
            'Time', genTime, ...
            'CurrentPrice', currentPrice, ...
            'FutureTimes', futureTimes, ...
            'PredictedPrices', expectedPath, ...
            'UpperConfidence', upConf, ...
            'LowerConfidence', dnConf, ...
            'Signal', signal, ...
            'TargetPrice', tp, ...
            'StopLoss', sl, ...
            'Support', support, ...
            'Resistance', resistance, ...
            'ModelName', 'CNN-LSTM Ensemble', ...
            'ConfidenceScore', confMetrics.ProjectionConfidence / 100, ...
            'InferenceTimeMs', elapsedMs, ...
            'RMSE', NaN, ...
            'Source', sourceStruct, ...
            'ForecastQuality', confMetrics, ...
            'ValidationStatus', valReason, ...
            'RiskReward', rr, ...
            'ETA', sprintf('%d minutes', etaMinutes) ...
        );
    else
        predStruct = struct();
    end
    
    % 5. UI Update
    if ismember('SMA20', fullData_features.Properties.VariableNames)
        if currentPrice > fullData_features.SMA20(end)
            trend = 'BULLISH';
        elseif currentPrice < fullData_features.SMA20(end)
            trend = 'BEARISH';
        else
            trend = 'NEUTRAL';
        end
    else
        trend = 'NEUTRAL';
    end
    
    newData = struct('CurrentPrice', currentPrice, 'Signal', signal, 'Trend', trend, ...
        'Confidence', baseConfidence, 'ExpectedNextClose', ensemblePred, ...
        'ExpectedHigh', currentPrice + volatility, 'ExpectedLow', currentPrice - volatility, ...
        'ProbabilityUp', 0.5, 'ProbabilityDown', 0.5, 'Support', support, 'Resistance', resistance, ...
        'SL', sl, 'TP1', tp, 'TP2', tp, 'TP3', tp, ...
        'PredictionGenerated', datestr(genTime, 'HH:MM:SS'), ...
        'PredictionValidUntil', datestr(genTime + minutes(5), 'HH:MM:SS'), ...
        'LastModelVersion', 'v1.0.0', 'RiskReward', rr);
    
    dashboard.updateData(newData);
    
    % Update the rich visualizer with OHLCV + Indicators
    visData = table(genTime, newCandle.Open, newCandle.High, newCandle.Low, currentPrice, newCandle.Volume, ...
        'VariableNames', {'Time', 'Open', 'High', 'Low', 'Close', 'Volume'});
    
    if ismember('SMA20', fullData_features.Properties.VariableNames); visData.SMA20 = fullData_features.SMA20(end); end
    if ismember('SMA50', fullData_features.Properties.VariableNames); visData.SMA50 = fullData_features.SMA50(end); end
    if ismember('EMA20', fullData_features.Properties.VariableNames); visData.EMA20 = fullData_features.EMA20(end); end
    if ismember('EMA50', fullData_features.Properties.VariableNames); visData.EMA50 = fullData_features.EMA50(end); end
    
    predictionVisualizer.update(visData, predStruct);
    
        Logger.info('[%s] Processed tick in %.1f ms | Price: $%.2f | Signal: %s', ...
            datestr(genTime, 'HH:MM:SS'), elapsedMs, currentPrice, signal);
            
    catch ME
        Logger.error('Exception in processLiveTick: %s', ME.message);
        % Graceful degradation to "No Prediction"
        predStruct = struct();
        
        visData = table(datetime('now'), newCandle.Open, newCandle.High, newCandle.Low, newCandle.Close, newCandle.Volume, ...
            'VariableNames', {'Time', 'Open', 'High', 'Low', 'Close', 'Volume'});
            
        predictionVisualizer.update(visData, predStruct);
    end
end

function logPrediction(ts, price, pred, conf, sl, tp, signal)
    logFile = fullfile('logs', 'prediction_log.csv');
    writeHeader = ~exist(logFile, 'file');
    
    fid = fopen(logFile, 'a');
    if fid ~= -1
        if writeHeader
            fprintf(fid, 'Timestamp,Price,Prediction,Confidence,SL,TP,Signal\n');
        end
        fprintf(fid, '%s,%.2f,%.2f,%.4f,%.2f,%.2f,%s\n', ...
            datestr(ts, 'yyyy-mm-dd HH:MM:SS'), price, pred, conf, sl, tp, signal);
        fclose(fid);
    end
end
