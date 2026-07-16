function test_prediction_render()
% test_prediction_render
% Standalone test to verify the UI without AI models

% clc; clear; close all;
addpath(genpath('src'));

disp('Starting UI Rendering Test...');

% Create figure and axes
fig = figure('Name', 'SentinelCrypto Prediction Visualizer Test', 'Color', [0.08 0.08 0.1], 'Position', [100 100 1200 800]);
ax = axes(fig, 'Color', [0.12 0.12 0.15], 'XColor', [0.5 0.5 0.5], 'YColor', [0.5 0.5 0.5]);
grid(ax, 'on');
hold(ax, 'on');

% 1. Create PriceChart
priceChart = PriceChart(ax);

% 2. Create PredictionChart
predChart = PredictionChart(ax);

% 3. Generate 150 historical candles
baseTime = datetime('now') - minutes(150 * 15);
times = baseTime + minutes((1:150)' * 15);
basePrice = 64000;
prices = basePrice + cumsum(randn(150, 1) * 20);

O = prices + randn(150, 1) * 5;
C = prices + randn(150, 1) * 5;
H = max([O, C], [], 2) + abs(randn(150, 1) * 10);
L = min([O, C], [], 2) - abs(randn(150, 1) * 10);
V = rand(150, 1) * 100;

histTable = table(times, O, H, L, C, V, 'VariableNames', {'Time', 'Open', 'High', 'Low', 'Close', 'Volume'});

% Update PriceChart
priceChart.update(histTable);

% 4. Generate prediction
predSteps = max(VisualizationConfig.ForecastHorizons.Steps);
genTime = times(end);
currentPrice = C(end);

futureMins = (1:predSteps)' * 15;
futureTimes = genTime + minutes(futureMins);
drifts = randn(predSteps, 1) * 0.002 + 0.001;
futurePreds = currentPrice * cumprod(1 + drifts);

expandingVol = 50 * sqrt(1:predSteps)';
upConf = futurePreds + expandingVol;
dnConf = futurePreds - expandingVol;

tp1 = currentPrice + 200;
sl = currentPrice - 100;
support = currentPrice - 150;
res = currentPrice + 250;

predStruct = struct(...
    'Time', genTime, ...
    'CurrentPrice', currentPrice, ...
    'FutureTimes', futureTimes, ...
    'PredictedPrices', futurePreds, ...
    'UpperConfidence', upConf, ...
    'LowerConfidence', dnConf, ...
    'Signal', 'BUY', ...
    'TargetPrice', tp1, ...
    'StopLoss', sl, ...
    'Support', support, ...
    'Resistance', res, ...
    'ModelName', 'Synthetic Test', ...
    'ConfidenceScore', 0.85, ...
    'InferenceTimeMs', 15.2, ...
    'RMSE', 12.5, ...
    'Source', struct('Projection', true, 'ModelPrediction', true), ...
    'ForecastQuality', struct('AdaptiveThreshold', 60, 'ProjectionConfidence', 85, 'ProjectionReliability', 90, 'ProjectionDrift', 5), ...
    'ValidationStatus', 'VALID', ...
    'RiskReward', 2.5, ...
    'ETA', '45 minutes' ...
);

% Update PredictionChart
predChart.update(predStruct);

disp('Render complete. Verify visual elements.');

end
