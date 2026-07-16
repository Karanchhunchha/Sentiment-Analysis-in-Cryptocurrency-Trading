% verify_results.m
% Validates claims made in documentation against actual recomputed performance metrics.
% Read-only verification (no retraining or model modification).

clc; clear; close all;

addpath(genpath('src'));
addpath(genpath('tests'));
addpath(genpath('data'));

fprintf('====================================================\n');
fprintf('     SENTINELCRYPTO CLAIM VERIFICATION SCRIPT       \n');
fprintf('====================================================\n');

%% Claimed Metrics
claimed_win_rate = 55.56;
claimed_total_return = 151.60;
claimed_max_drawdown = 38.11;
claimed_ruin_prob = 0.00;

%% 1. Recompute Metrics
fprintf('Loading data and recomputing metrics...\n');
try
    loader = PriceDataLoader('BTCUSDT', '1d');
    histData = [];
    if exist('data/market/btc.csv', 'file')
        histData = loader.loadHistoricalCSV('data/market/btc.csv');
    elseif exist('btc.csv', 'file')
        histData = loader.loadHistoricalCSV('btc.csv');
    end
    
    if isempty(histData)
        error('Could not find historical data (btc.csv).');
    end

    % Backtesting to get Win Rate, Return, and Drawdown
    re = RiskEngine(1.5, 3.0, 1.5);
    bt = Backtester([], re, histData);
    btResults = bt.run();
    
    % Monte Carlo to get Probability of Ruin
    mcs = MonteCarloSimulator(btResults.WinRate / 100, 0.05, -0.02, 10000);
    mcResults = mcs.runSimulations(10000, 252);

    actual_win_rate = btResults.WinRate;
    actual_total_return = btResults.ReturnPct;
    actual_max_drawdown = btResults.MaxDrawdown;
    actual_ruin_prob = mcResults.ProbabilityOfRuin;
    
    fprintf('\n--- VERIFICATION RESULTS ---\n');
    
    % Verify Win Rate
    if abs(actual_win_rate - claimed_win_rate) < 1.0
        fprintf('Win Rate: PASS (Claimed: %.2f%%, Actual: %.2f%%)\n', claimed_win_rate, actual_win_rate);
    else
        fprintf('Win Rate: DISCREPANCY (Claimed: %.2f%%, Actual: %.2f%%)\n', claimed_win_rate, actual_win_rate);
    end
    
    % Verify Total Return
    if abs(actual_total_return - claimed_total_return) < 2.0
        fprintf('Total Return: PASS (Claimed: %.2f%%, Actual: %.2f%%)\n', claimed_total_return, actual_total_return);
    else
        fprintf('Total Return: DISCREPANCY (Claimed: %.2f%%, Actual: %.2f%%)\n', claimed_total_return, actual_total_return);
    end
    
    % Verify Max Drawdown
    if abs(actual_max_drawdown - claimed_max_drawdown) < 1.0
        fprintf('Max Drawdown: PASS (Claimed: %.2f%%, Actual: %.2f%%)\n', claimed_max_drawdown, actual_max_drawdown);
    else
        fprintf('Max Drawdown: DISCREPANCY (Claimed: %.2f%%, Actual: %.2f%%)\n', claimed_max_drawdown, actual_max_drawdown);
    end
    
    % Verify Probability of Ruin
    if abs(actual_ruin_prob - claimed_ruin_prob) < 0.1
        fprintf('Probability of Ruin: PASS (Claimed: %.2f%%, Actual: %.2f%%)\n', claimed_ruin_prob, actual_ruin_prob);
    else
        fprintf('Probability of Ruin: DISCREPANCY (Claimed: %.2f%%, Actual: %.2f%%)\n', claimed_ruin_prob, actual_ruin_prob);
    end
    
catch ME
    fprintf('Error during verification: %s\n', ME.message);
end

fprintf('====================================================\n');
