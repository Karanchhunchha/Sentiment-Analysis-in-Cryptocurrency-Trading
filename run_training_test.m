% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto
% run_training_test.m

clc; clear;
addpath('models');
addpath('data_ingestion');

disp('1. Generating historical market data (1000 candles, 8 features)...');
% Features: Open, High, Low, Close, Vol, RSI, Sentiment, Liquidity
numSamples = 1000;
numFeatures = 8;
rawData = randn(numSamples, numFeatures); 
% Make Close price a realistic random walk
rawData(:, 4) = 50000 + cumsum(randn(numSamples, 1) * 500); 

disp('2. Building Sequences via MarketSequenceBuilder...');
builder = MarketSequenceBuilder(30, 1);
[X, Y] = builder.buildWalkForwardSequences(rawData);

% Convert 3D tensor to cell array for MATLAB trainNetwork sequence input
disp('3. Formatting data for Deep Learning Toolbox...');
numWindows = size(X, 3);
XTrain = cell(numWindows, 1);
YTrain = Y';
for i = 1:numWindows
    XTrain{i} = X(:, :, i);
end

disp('4. Initializing and Training HybridForecastNet (Short 5-epoch test run)...');
net = HybridForecastNet(numFeatures, 30);

% Override options for a quick terminal test run
net.NetworkOptions = trainingOptions('adam', ...
    'MaxEpochs', 5, ...
    'MiniBatchSize', 64, ...
    'Verbose', true, ...
    'VerboseFrequency', 1, ...
    'Plots', 'none');

net.train(XTrain, YTrain);

disp('✅ Training Test Complete!');
