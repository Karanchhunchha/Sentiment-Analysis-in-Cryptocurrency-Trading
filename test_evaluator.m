% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto
% test_evaluator.m

clc; clear;
addpath('models');

evaluator = ForecastEvaluator();

currentPrice = 64500.00;
predictedPrice = 65800.00; % Bullish forecast (+2.01%)
sentimentScore = 0.85;     % Bullish sentiment
rsi = 55.0;                % Healthy RSI (not overbought/oversold)
liquidityStatus = 'High';  % Healthy liquidity

report = evaluator.generateSignal(currentPrice, predictedPrice, sentimentScore, rsi, liquidityStatus);

disp(report);
