% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto
% run_end_to_end_integration.m

clc; clear;
addpath('models');
addpath('data_ingestion');
addpath('portfolio');
addpath('sentiment_analysis');

disp('================================================');
disp('   🚀 SENTINELCRYPTO END-TO-END INTEGRATION 🚀   ');
disp('================================================');

%% 1. Data Ingestion (Real Binance Data)
fetcher = BinanceDataFetcher();
% Fetch 1000 hours of real BTCUSDT data
marketData = fetcher.fetchHistoricalData('BTCUSDT', '1h', 1000);

% Since historical Twitter data requires paid API keys, we simulate historical 
% sentiment scores here to complete the feature matrix for training. 
% In live deployment, SentimentFusion.m is called on fresh tweets.
disp('🧠 Augmenting data with historical sentiment proxy...');
simSentiment = filter([0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1], 1, randn(1000, 1));
simSentiment = (simSentiment - min(simSentiment)) / (max(simSentiment) - min(simSentiment)) * 2 - 1;
marketData.Sentiment = simSentiment;

%% 2. Train / Test Split
trainSize = 800;
trainData = marketData(1:trainSize, :);
testData = marketData(trainSize+1:end, :);

testPrices = testData.Close; % For backtesting later

%% 3. Build Sequences (Walk-Forward)
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

%% 4. Train Hybrid Forecast Net
numFeatures = size(marketData, 2);
net = HybridForecastNet(numFeatures, 30);
% Short training for integration test
net.NetworkOptions = trainingOptions('adam', 'MaxEpochs', 5, 'MiniBatchSize', 32, 'Verbose', false, 'Plots', 'none');
net.train(XTrain, YTrain);

%% 5. Generate Real Predictions
disp(' ');
disp('🔮 Generating Predictions on OOS Test Set...');
YPred = net.predict(XTest);

% Note: YPred contains normalized predicted future prices relative to the window.
% We convert this into an expected return signal for the optimizer.
expectedReturns = YPred * 0.05; % Scale to realistic expected return magnitudes
volatility = ones(length(YPred), 1) * 0.02; % Constant volatility assumption

%% 6. Portfolio Optimization
disp('⚖️ Optimizing Portfolio Weights based on Predictions...');
optimizer = PortfolioOptimizer(2.0);
targetWeightsBTC = zeros(length(YPred), 1);
for t = 1:length(YPred)
    w = optimizer.optimize(expectedReturns(t), volatility(t));
    targetWeightsBTC(t) = w(1);
end

%% 7. Backtesting
disp(' ');
tester = Backtester(10000, 0.0015);
% The prices align with the end of the test sequences
alignedTestPrices = testPrices(30:end); 
results = tester.run(alignedTestPrices, targetWeightsBTC);

disp('================================================');
disp('   ✅ END-TO-END INTEGRATION TEST COMPLETE ✅    ');
disp('================================================');
