classdef PaperTrader < handle
    % PaperTrader Simulates paper trading forward in time, collecting deep
    % institutional financial metrics over 1000+ trades.
    
    properties
        InitialCapital
        CurrentCapital
        Trades
        EquityCurve
    end
    
    methods
        function obj = PaperTrader(initialCapital)
            if nargin < 1; initialCapital = 10000; end
            obj.InitialCapital = initialCapital;
            obj.CurrentCapital = initialCapital;
            obj.Trades = table();
            obj.EquityCurve = [initialCapital];
        end
        
        function logTrade(obj, entryTime, exitTime, entryPrice, exitPrice, isLong)
            % Simplified logging for the simulator
            if isLong
                profit = exitPrice - entryPrice;
            else
                profit = entryPrice - exitPrice;
            end
            
            % Very basic 1-unit position sizing for demonstration
            obj.CurrentCapital = obj.CurrentCapital + profit;
            
            % Duration
            durationHours = hours(exitTime - entryTime);
            
            newTrade = {entryTime, exitTime, durationHours, entryPrice, exitPrice, profit, obj.CurrentCapital};
            
            if isempty(obj.Trades)
                obj.Trades = cell2table(newTrade, 'VariableNames', ...
                    {'EntryTime', 'ExitTime', 'DurationHours', 'EntryPrice', 'ExitPrice', 'Profit', 'Equity'});
            else
                obj.Trades = [obj.Trades; newTrade];
            end
            
            obj.EquityCurve(end+1) = obj.CurrentCapital;
        end
        
        function results = calculateMetrics(obj)
            % Calculate Institutional Metrics
            numTrades = height(obj.Trades);
            if numTrades < 2
                results = struct();
                return;
            end
            
            profits = obj.Trades.Profit;
            wins = profits > 0;
            losses = profits <= 0;
            
            grossProfit = sum(profits(wins));
            grossLoss = abs(sum(profits(losses)));
            
            winRate = (sum(wins) / numTrades) * 100;
            profitFactor = grossProfit / max(grossLoss, 1e-8);
            
            avgWin = mean(profits(wins));
            avgLoss = mean(profits(losses));
            if isnan(avgWin); avgWin = 0; end
            if isnan(avgLoss); avgLoss = 0; end
            
            expectancy = (winRate/100 * avgWin) - ((1 - winRate/100) * abs(avgLoss));
            
            % Risk Adjusted Returns (Assuming daily trading roughly, simple proxy)
            returns = diff(obj.EquityCurve) ./ obj.EquityCurve(1:end-1);
            riskFreeRate = 0.02 / 365; % Daily proxy for 2% annual
            
            % Sharpe Ratio (Annualized proxy)
            sharpe = sqrt(365) * ((mean(returns) - riskFreeRate) / max(std(returns), 1e-8));
            
            % Sortino Ratio (Annualized proxy)
            downsideReturns = returns(returns < 0);
            sortino = sqrt(365) * ((mean(returns) - riskFreeRate) / max(std(downsideReturns), 1e-8));
            
            % Drawdown
            peaks = cummax(obj.EquityCurve);
            drawdowns = (peaks - obj.EquityCurve') ./ peaks;
            maxDrawdown = max(drawdowns) * 100;
            
            % Calmar Ratio
            annReturn = (obj.CurrentCapital - obj.InitialCapital) / obj.InitialCapital; % rough
            calmar = annReturn / max(maxDrawdown/100, 1e-8);
            
            results = struct();
            results.TotalTrades = numTrades;
            results.WinRate = winRate;
            results.ProfitFactor = profitFactor;
            results.Expectancy = expectancy;
            results.SharpeRatio = sharpe;
            results.SortinoRatio = sortino;
            results.CalmarRatio = calmar;
            results.MaxDrawdown = maxDrawdown;
            results.AvgHoldTimeHours = mean(obj.Trades.DurationHours);
            
            obj.printReport(results);
        end
        
        function printReport(~, results)
            fprintf('\n======================================================\n');
            fprintf('        PAPER TRADING SIMULATION METRICS              \n');
            fprintf('======================================================\n');
            fprintf('Total Trades:        %d\n', results.TotalTrades);
            fprintf('Win Rate:            %.2f%%\n', results.WinRate);
            fprintf('Profit Factor:       %.2f\n', results.ProfitFactor);
            fprintf('Expectancy:          $%.2f per trade\n', results.Expectancy);
            fprintf('Avg Hold Time:       %.2f hours\n', results.AvgHoldTimeHours);
            fprintf('Max Drawdown:        %.2f%%\n', results.MaxDrawdown);
            fprintf('Sharpe Ratio:        %.2f\n', results.SharpeRatio);
            fprintf('Sortino Ratio:       %.2f\n', results.SortinoRatio);
            fprintf('Calmar Ratio:        %.2f\n', results.CalmarRatio);
            fprintf('======================================================\n');
        end
    end
end
