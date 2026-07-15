%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto
% evaluate_pipeline.m (Evaluation & Backtesting Mode)

clc; clear; close all;

%% Configure Paths
addpath(genpath('src'));
addpath(genpath('data'));
addpath(genpath('logs'));

disp('====================================================');
disp('    📊 SENTINELCRYPTO EVALUATION PIPELINE 📊     ');
disp('====================================================');

%% 1. Load Prediction Log
logFile = fullfile('logs', 'prediction_log.csv');
if ~exist(logFile, 'file')
    Logger.error('No prediction log found at %s. Run run_pipeline.m first.', logFile);
    return;
end

disp('-> Loading prediction history...');
preds = readtable(logFile);
if height(preds) < 2
    Logger.warning('Not enough data in prediction_log to evaluate.');
    return;
end

% Standardize times
preds.Timestamp = datetime(preds.Timestamp);

%% 2. Calculate Evaluation Metrics
disp('-> Computing Performance Metrics...');

% In a true evaluation, we compare 'Prediction' made at T-1 against 'Price' at T.
% Shift prices up by 1 to represent the actual price that occurred after prediction.
actualNextPrice = [preds.Price(2:end); NaN];
predictedNextPrice = preds.Prediction;

% Clean NaNs
validIdx = ~isnan(actualNextPrice) & ~isnan(predictedNextPrice);
yTrue = actualNextPrice(validIdx);
yPred = predictedNextPrice(validIdx);
signals = preds.Signal(validIdx);
entryPrices = preds.Price(validIdx);

% 2.1 Regression Metrics
rmse = sqrt(mean((yTrue - yPred).^2));
mae = mean(abs(yTrue - yPred));

% 2.2 Classification Metrics (Directional Accuracy)
actualDir = sign(yTrue - entryPrices);
predDir = sign(yPred - entryPrices);

% Avoid zeros
actualDir(actualDir == 0) = 1; 
predDir(predDir == 0) = 1;

accuracy = sum(actualDir == predDir) / length(yTrue);

% 2.3 Trading Metrics (Simplified PnL simulation based on signals)
returns = zeros(length(yTrue), 1);
for i = 1:length(yTrue)
    pctChange = (yTrue(i) - entryPrices(i)) / entryPrices(i);
    if strcmp(signals{i}, 'BUY')
        returns(i) = pctChange;
    elseif strcmp(signals{i}, 'SELL')
        returns(i) = -pctChange;
    end
    % HOLD yields 0 return for that period
end

winRate = sum(returns > 0) / sum(returns ~= 0);
if isnan(winRate); winRate = 0; end

grossProfit = sum(returns(returns > 0));
grossLoss = abs(sum(returns(returns < 0)));
if grossLoss == 0; profitFactor = Inf; else; profitFactor = grossProfit / grossLoss; end

% Portfolio Metrics (Assuming risk-free rate = 0)
% Annualization factor for 5m candles = (24*60/5) * 365 = 105120
annFactor = 105120;
sharpe = (mean(returns) / std(returns)) * sqrt(annFactor);

downsideReturns = returns(returns < 0);
sortino = (mean(returns) / std(downsideReturns)) * sqrt(annFactor);

cumReturns = cumprod(1 + returns);
peak = cummax(cumReturns);
drawdown = (cumReturns - peak) ./ peak;
mdd = min(drawdown);

%% 3. Display Report
disp('====================================================');
disp('               PERFORMANCE REPORT                   ');
disp('====================================================');
fprintf('Total Predictions : %d\n', length(yTrue));
fprintf('Directional Acc.  : %.2f%%\n', accuracy * 100);
fprintf('Win Rate          : %.2f%%\n', winRate * 100);
fprintf('Profit Factor     : %.2f\n', profitFactor);
disp('----------------------------------------------------');
fprintf('RMSE              : $%.2f\n', rmse);
fprintf('MAE               : $%.2f\n', mae);
disp('----------------------------------------------------');
fprintf('Sharpe Ratio      : %.2f\n', sharpe);
fprintf('Sortino Ratio     : %.2f\n', sortino);
fprintf('Max Drawdown      : %.2f%%\n', mdd * 100);
disp('====================================================');
