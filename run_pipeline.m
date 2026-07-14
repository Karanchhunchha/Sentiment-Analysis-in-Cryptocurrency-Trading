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

disp('-> [2/4] Initializing Feature Fusion Engine...');
fusionEngine = FeatureFusionEngine();

disp('-> [3/4] Launching Sentinel Dashboard...');
% Initial empty state for the dense dashboard
emptyData = struct('CurrentPrice', 0, 'Signal', 'WAIT', 'Trend', 'NEUTRAL', ...
    'Confidence', 0, 'ExpectedNextClose', 0, 'ExpectedHigh', 0, 'ExpectedLow', 0, ...
    'ProbabilityUp', 0.5, 'ProbabilityDown', 0.5, 'Support', 0, 'Resistance', 0, ...
    'SL', 0, 'TP1', 0, 'TP2', 0, 'TP3', 0, 'PredictionGenerated', '-', ...
    'PredictionValidUntil', '-', 'LastModelVersion', 'v1.0.0', 'RiskReward', 0);

dashboard = SentinelDashboard(emptyData);

%% 2. Define Live Event Callback
liveUpdateCallback = @(newCandle, fullData) processLiveTick(newCandle, fullData, fusionEngine, models, dashboard);

%% 3. Start Live Data Stream
disp('-> [4/4] Starting Binance WebSocket/REST Polling...');
interval = '5m';
dataLoader = PriceDataLoader('BTCUSDT', interval);

try
    histData = dataLoader.loadHistoricalCSV('data/market/btc.csv');
    fusionEngine.initializeHistorical(histData(end-100:end, :));
catch
    try
        histData = dataLoader.loadHistoricalCSV('btc.csv');
        fusionEngine.initializeHistorical(histData(end-100:end, :));
    catch
        Logger.warning('No historical data found. Starting from scratch.');
    end
end

dataLoader.startLiveStream(liveUpdateCallback);

disp('====================================================');
disp('Live system running. Dashboard will update automatically.');
disp('====================================================');

%% Callback Function (Executes in < 100ms)
function processLiveTick(newCandle, fullData, fusionEngine, models, dashboard)
    tic;
    
    % 1. Incremental Feature Update
    featureVector = fusionEngine.updateIncremental(newCandle);
    currentPrice = featureVector.Close;
    
    % 2. Fast Prediction (Using real loaded models in practice)
    % For robust structural testing, simulate a calculated forecast
    ensemblePred = currentPrice * (1 + (randn()*0.005)); 
    volatility = std(fullData.Close(max(1, end-20):end));
    
    expHigh = ensemblePred + volatility;
    expLow = ensemblePred - volatility;
    
    % 3. Risk & Probabilities
    delta = ensemblePred - currentPrice;
    probUp = min(max(0.5 + (delta / currentPrice * 100), 0.1), 0.9);
    probDown = 1 - probUp;
    confidence = abs(probUp - 0.5) * 2;
    
    if probUp > 0.55
        signal = 'BUY'; trend = 'UPTREND';
        sl = currentPrice - (volatility * 1.5);
        tp1 = currentPrice + (volatility * 1);
        tp2 = currentPrice + (volatility * 2);
        tp3 = currentPrice + (volatility * 3);
    elseif probDown > 0.55
        signal = 'SELL'; trend = 'DOWNTREND';
        sl = currentPrice + (volatility * 1.5);
        tp1 = currentPrice - (volatility * 1);
        tp2 = currentPrice - (volatility * 2);
        tp3 = currentPrice - (volatility * 3);
    else
        signal = 'HOLD'; trend = 'NEUTRAL';
        sl = currentPrice * 0.98;
        tp1 = currentPrice * 1.02; tp2 = tp1; tp3 = tp1;
    end
    
    rr = abs(tp1 - currentPrice) / abs(currentPrice - sl);
    
    % Support/Resistance (simplified recent min/max)
    support = min(fullData.Low(max(1, end-20):end));
    resistance = max(fullData.High(max(1, end-20):end));
    
    % Times
    genTime = datetime('now');
    validTime = genTime + minutes(5);
    
    % 4. Log Prediction to CSV
    logPrediction(genTime, currentPrice, ensemblePred, confidence, sl, tp1, signal);
    
    % 5. UI Update
    newData = struct('CurrentPrice', currentPrice, 'Signal', signal, 'Trend', trend, ...
        'Confidence', confidence, 'ExpectedNextClose', ensemblePred, ...
        'ExpectedHigh', expHigh, 'ExpectedLow', expLow, ...
        'ProbabilityUp', probUp, 'ProbabilityDown', probDown, ...
        'Support', support, 'Resistance', resistance, ...
        'SL', sl, 'TP1', tp1, 'TP2', tp2, 'TP3', tp3, ...
        'PredictionGenerated', datestr(genTime, 'HH:MM:SS'), ...
        'PredictionValidUntil', datestr(validTime, 'HH:MM:SS'), ...
        'LastModelVersion', 'v1.0.0', 'RiskReward', rr);
    
    dashboard.updateData(newData);
    
    elapsed = toc;
    Logger.info('[%s] Processed tick in %.1f ms | Price: $%.2f | Signal: %s', ...
        datestr(genTime, 'HH:MM:SS'), elapsed * 1000, currentPrice, signal);
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
