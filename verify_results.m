% verify_results.m
% Validates claims made in documentation against actual recomputed performance metrics.
% Read-only verification (no retraining or model modification).

clc; clear; close all;
rng(42); % Fixed for reproducibility

addpath(genpath('src'));
addpath(genpath('tests'));
addpath(genpath('data'));

fprintf('====================================================\n');
fprintf('     SENTINELCRYPTO CLAIM VERIFICATION SCRIPT       \n');
fprintf('====================================================\n');

%% Claimed Metrics (Updated to match actual out-of-sample verified walk-forward results)
    claimed_win_rate = 39.10;
    claimed_total_return = -78.88;
    claimed_max_drawdown = 81.00;
    claimed_ruin_prob = 99.99;

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
    
    % Monte Carlo to get Probability of Ruin (empirical bootstrap on real per-trade P&L)
    mcs = MonteCarloSimulator(0, 0, 0, 10000);
    if isempty(btResults.TradeLog) || height(btResults.TradeLog) == 0
        error('verify_results:EmpiricalMCEmpty','Cannot bootstrap Monte Carlo from empty TradeLog.');
    end
    mcResults = mcs.runEmpirical(btResults.TradeLog, 10000, 42);

    actual_win_rate = btResults.WinRate;
    actual_total_return = btResults.ReturnPct;
    actual_max_drawdown = btResults.MaxDrawdown;
    actual_ruin_prob = mcResults.ProbabilityOfRuin;
    
    fprintf('\n--- VERIFICATION RESULTS ---\n');
    
    % Verify Win Rate
    if abs(actual_win_rate - claimed_win_rate) < 1.5
        fprintf('Win Rate: PASS (Claimed: %.2f%%, Actual: %.2f%%)\n', claimed_win_rate, actual_win_rate);
    else
        error('verify_results:ClaimMismatch', 'Win Rate DISCREPANCY (Claimed: %.2f%%, Actual: %.2f%%)', claimed_win_rate, actual_win_rate);
    end
    
    % Verify Total Return
    if abs(actual_total_return - claimed_total_return) < 2.5
        fprintf('Total Return: PASS (Claimed: %.2f%%, Actual: %.2f%%)\n', claimed_total_return, actual_total_return);
    else
        error('verify_results:ClaimMismatch', 'Total Return DISCREPANCY (Claimed: %.2f%%, Actual: %.2f%%)', claimed_total_return, actual_total_return);
    end
    
    % Verify Max Drawdown
    if abs(actual_max_drawdown - claimed_max_drawdown) < 1.5
        fprintf('Max Drawdown: PASS (Claimed: %.2f%%, Actual: %.2f%%)\n', claimed_max_drawdown, actual_max_drawdown);
    else
        error('verify_results:ClaimMismatch', 'Max Drawdown DISCREPANCY (Claimed: %.2f%%, Actual: %.2f%%)', claimed_max_drawdown, actual_max_drawdown);
    end
    
    % Verify Probability of Ruin
    if abs(actual_ruin_prob - claimed_ruin_prob) < 0.5
        fprintf('Probability of Ruin: PASS (Claimed: %.2f%%, Actual: %.2f%%)\n', claimed_ruin_prob, actual_ruin_prob);
    else
        error('verify_results:ClaimMismatch', 'Probability of Ruin DISCREPANCY (Claimed: %.2f%%, Actual: %.2f%%)', claimed_ruin_prob, actual_ruin_prob);
    end
    
    fprintf('\n✅ VERIFICATION SUCCESSFUL: All recomputed metrics match authenticated walk-forward baseline.\n');
    
catch ME
    fprintf('❌ VERIFICATION FAILED: %s\n', ME.message);
    exit(1); % Fail non-zero so CI / verification runner captures failure
end

fprintf('====================================================\n');
