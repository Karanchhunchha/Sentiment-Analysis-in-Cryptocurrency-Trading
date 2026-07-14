% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto
% test_backtest.m

clc; clear;
addpath('portfolio');

disp('1. Simulating 365 days of historical prices and model signals...');
numDays = 365;
prices = 50000 + cumsum(randn(numDays, 1) * 1000); % Random walk BTC price
prices(prices < 1000) = 1000; % Prevent negative prices

% Simulated model signals: 
% We predict expected return. If > 0, we want to buy BTC.
expectedReturns = randn(numDays, 1) * 0.05; 
volatility = ones(numDays, 1) * 0.02; % Constant simulated volatility

disp('2. Running PortfolioOptimizer to generate target weights...');
optimizer = PortfolioOptimizer(2.0);
targetWeightsBTC = zeros(numDays, 1);
for t = 1:numDays
    w = optimizer.optimize(expectedReturns(t), volatility(t));
    targetWeightsBTC(t) = w(1); % Store the BTC weight
end

disp('3. Initializing Backtester (Initial Capital: $10,000, Fee: 0.15%)...');
tester = Backtester(10000, 0.0015);

% Run backtest
results = tester.run(prices, targetWeightsBTC);
