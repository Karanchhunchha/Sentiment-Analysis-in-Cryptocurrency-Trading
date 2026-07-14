% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto

classdef Backtester < handle
    % BACKTESTER Simulates a trading strategy against historical prices
    % Evaluates the model-driven strategy against a Buy & Hold baseline,
    % properly accounting for transaction costs (Binance 0.15% standard).
    
    properties
        InitialCapital = 10000;
        TransactionCost = 0.0015; % 0.15% per trade
    end
    
    methods
        function obj = Backtester(initialCapital, tCost)
            if nargin >= 1; obj.InitialCapital = initialCapital; end
            if nargin >= 2; obj.TransactionCost = tCost; end
        end
        
        function results = run(obj, prices, targetWeightsBTC)
            % prices: Nx1 vector of actual historical prices
            % targetWeightsBTC: Nx1 vector of desired portfolio allocation to BTC (0 to 1)
            
            numSteps = length(prices);
            
            % Strategy Tracking
            capital_Strat = zeros(numSteps, 1);
            capital_Strat(1) = obj.InitialCapital;
            btcHoldings_Strat = 0;
            cashHoldings_Strat = obj.InitialCapital;
            currentWeightBTC = 0;
            totalTrades = 0;
            
            % Baseline Tracking (Buy & Hold)
            capital_BH = zeros(numSteps, 1);
            capital_BH(1) = obj.InitialCapital;
            btcHoldings_BH = obj.InitialCapital / prices(1); % Buy all at step 1
            
            disp('================================================');
            disp('   📈 Running Strategy Backtest... ');
            disp('================================================');
            
            for t = 2:numSteps
                % 1. Mark to Market (Update portfolio values based on new price)
                capital_Strat(t) = cashHoldings_Strat + (btcHoldings_Strat * prices(t));
                capital_BH(t) = btcHoldings_BH * prices(t);
                
                % 2. Check Rebalance requirement
                targetW = targetWeightsBTC(t-1); % Use yesterday's signal for today's rebalance
                currentW = (btcHoldings_Strat * prices(t)) / capital_Strat(t);
                
                % Only trade if the required allocation change is > 5% to avoid micro-trades
                if abs(targetW - currentW) > 0.05
                    totalTrades = totalTrades + 1;
                    
                    targetBTCValue = capital_Strat(t) * targetW;
                    currentBTCValue = btcHoldings_Strat * prices(t);
                    
                    valueToTrade = abs(targetBTCValue - currentBTCValue);
                    cost = valueToTrade * obj.TransactionCost;
                    
                    % Deduct cost from capital
                    capital_Strat(t) = capital_Strat(t) - cost;
                    
                    % Execute trade
                    cashHoldings_Strat = capital_Strat(t) * (1 - targetW);
                    btcHoldings_Strat = (capital_Strat(t) * targetW) / prices(t);
                end
            end
            
            % Calculate Metrics
            results.Strategy = obj.calculateMetrics(capital_Strat);
            results.Strategy.TotalTrades = totalTrades;
            
            results.BuyAndHold = obj.calculateMetrics(capital_BH);
            results.BuyAndHold.TotalTrades = 1;
            
            % Print Results
            obj.printReport(results);
        end
        
        function metrics = calculateMetrics(obj, capitalSeries)
            % Calculates standard quant metrics
            dailyReturns = diff(capitalSeries) ./ capitalSeries(1:end-1);
            
            % PnL
            metrics.NetPnL_Pct = ((capitalSeries(end) / capitalSeries(1)) - 1) * 100;
            
            % Sharpe (Assuming daily steps, annualized = sqrt(365))
            avgReturn = mean(dailyReturns);
            stdReturn = std(dailyReturns);
            if stdReturn == 0; stdReturn = 1e-6; end
            metrics.Sharpe = (avgReturn / stdReturn) * sqrt(365);
            
            % Sortino (Downside risk only)
            downsideReturns = dailyReturns(dailyReturns < 0);
            downsideStd = std(downsideReturns);
            if downsideStd == 0 || isnan(downsideStd); downsideStd = 1e-6; end
            metrics.Sortino = (avgReturn / downsideStd) * sqrt(365);
            
            % Maximum Drawdown
            cumulativeMax = cummax(capitalSeries);
            drawdowns = (capitalSeries - cumulativeMax) ./ cumulativeMax;
            metrics.MaxDrawdown_Pct = min(drawdowns) * 100;
        end
        
        function printReport(obj, results)
            disp(' ');
            disp('================================================');
            disp('           BACKTEST PERFORMANCE REPORT          ');
            disp('================================================');
            disp('Metric                  | Strategy   | Buy & Hold');
            disp('------------------------|------------|-----------');
            fprintf('Net Return (PnL)        | %7.2f%%  | %7.2f%%\n', results.Strategy.NetPnL_Pct, results.BuyAndHold.NetPnL_Pct);
            fprintf('Sharpe Ratio            | %7.2f    | %7.2f\n', results.Strategy.Sharpe, results.BuyAndHold.Sharpe);
            fprintf('Sortino Ratio           | %7.2f    | %7.2f\n', results.Strategy.Sortino, results.BuyAndHold.Sortino);
            fprintf('Max Drawdown            | %7.2f%%  | %7.2f%%\n', results.Strategy.MaxDrawdown_Pct, results.BuyAndHold.MaxDrawdown_Pct);
            fprintf('Total Trades Executed   | %7d    | %7d\n', results.Strategy.TotalTrades, results.BuyAndHold.TotalTrades);
            disp('================================================');
        end
    end
end
