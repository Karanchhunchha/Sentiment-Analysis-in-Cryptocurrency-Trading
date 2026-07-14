% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto
% main.m (Master Orchestrator)

clc; clear;
addpath('models');
addpath('data_ingestion');
addpath('portfolio');
addpath('sentiment_analysis');

disp('================================================');
disp('   🚀 SENTINELCRYPTO END-TO-END PIPELINE 🚀   ');
disp('================================================');

%% 1. Data Ingestion
fetcher = BinanceDataFetcher();
marketData = fetcher.fetchHistoricalData('BTCUSDT', '1h', 1000);

% Proxy for historical sentiment (simulating live text scoring)
simSentiment = filter([0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1], 1, randn(1000, 1));
simSentiment = (simSentiment - min(simSentiment)) / (max(simSentiment) - min(simSentiment)) * 2 - 1;
marketData.Sentiment = simSentiment;

%% 2. Data Splitting
trainSize = 800;
trainData = marketData(1:trainSize, :);
testData = marketData(trainSize+1:end, :);
testPrices = testData.Close; 

%% 3. Walk-Forward Sequence Generation
builder = MarketSequenceBuilder(30, 1);
disp(' ');
disp('--- Processing Training Set ---');
[XTrain3D, YTrainRaw] = builder.buildWalkForwardSequences(trainData);
disp(' ');
disp('--- Processing Test Set ---');
[XTest3D, YTestRaw] = builder.buildWalkForwardSequences(testData);

% Format for DL Toolbox
XTrain = cell(size(XTrain3D, 3), 1);
for i = 1:size(XTrain3D, 3); XTrain{i} = XTrain3D(:, :, i); end
YTrain = YTrainRaw';
XTest = cell(size(XTest3D, 3), 1);
for i = 1:size(XTest3D, 3); XTest{i} = XTest3D(:, :, i); end

%% 4. Model Training
numFeatures = size(marketData, 2);
net = HybridForecastNet(numFeatures, 30);
net.NetworkOptions = trainingOptions('adam', 'MaxEpochs', 5, 'MiniBatchSize', 32, 'Verbose', false, 'Plots', 'training-progress');
net.train(XTrain, YTrain);

%% 5. Inference
disp(' ');
disp('🔮 Generating Predictions on OOS Test Set...');
YPred = net.predict(XTest);
expectedReturns = YPred * 0.05; 
volatility = ones(length(YPred), 1) * 0.02;

%% 6. Portfolio Optimization
disp('⚖️ Optimizing Portfolio Weights based on Predictions...');
optimizer = PortfolioOptimizer(2.0);
targetWeightsBTC = zeros(length(YPred), 1);
for t = 1:length(YPred)
    w = optimizer.optimize(expectedReturns(t), volatility(t));
    targetWeightsBTC(t) = w(1);
end

%% 7. Strategy Backtesting & Evaluation
disp(' ');
tester = Backtester(10000, 0.0015);
alignedTestPrices = testPrices(30:end); 
results = tester.run(alignedTestPrices, targetWeightsBTC);

disp('================================================');
disp('   ✅ PIPELINE COMPLETE ✅    ');
disp('================================================');
