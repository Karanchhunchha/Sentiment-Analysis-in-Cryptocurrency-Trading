classdef MonteCarloSimulator < handle
    % MonteCarloSimulator Evaluates strategy robustness by bootstrapping
    % the empirical distribution of real per-trade returns (runEmpirical).
    % Computes Probability of Ruin, Expected Annual Return, and Drawdowns.
    
    properties
        InitialCapital
    end
    
    methods
        function obj = MonteCarloSimulator(initialCapital)
            if nargin < 1; initialCapital = 10000; end
            
            obj.InitialCapital = initialCapital;
        end
        
        function results = runEmpirical(obj, tradeLog, numSimulations, rngSeed)
            if nargin < 3 || isempty(numSimulations); numSimulations = 10000; end
            if nargin < 4; rngSeed = 42; end

            if istable(tradeLog)
                if ~ismember('NetPnL', tradeLog.Properties.VariableNames) || ~ismember('EquityBefore', tradeLog.Properties.VariableNames) || height(tradeLog) == 0
                    error('MonteCarloSimulator:EmptyTradeLog','TradeLog table must contain NetPnL and EquityBefore and cannot be empty.');
                end
                pn = [tradeLog.NetPnL];
                eb = [tradeLog.EquityBefore];
                if isempty(pn)
                    error('MonteCarloSimulator:EmptyTradeLog','TradeLog must contain NetPnL and EquityBefore and cannot be empty.');
                end
                tradeLog = struct('NetPnL', pn(:), 'EquityBefore', eb(:));
            elseif isstruct(tradeLog)
                if ~isfield(tradeLog, 'NetPnL') || ~isfield(tradeLog, 'EquityBefore') || isempty(tradeLog.NetPnL)
                    error('MonteCarloSimulator:EmptyTradeLog','TradeLog must be a struct/table with NetPnL and EquityBefore and cannot be empty.');
                end
            else
                error('MonteCarloSimulator:BadTradeLog','TradeLog must be a table or struct with NetPnL and EquityBefore.');
            end
            
            % Seed
            rng(rngSeed);
            
            % Derive returns
            returns = tradeLog.NetPnL ./ tradeLog.EquityBefore;
            numTrades = numel(returns);
            
            % Bootstrap simulations
            sampledReturns = randsample(returns, numTrades * numSimulations, true);
            sampledReturnsMatrix = reshape(sampledReturns, [numTrades, numSimulations]);
            
            % Calculate cumulative equity curves
            growthMatrix = 1 + sampledReturnsMatrix;
            equityCurves = obj.InitialCapital * cumprod(growthMatrix, 1);
            
            finalEquities = zeros(numSimulations, 1);
            maxDrawdowns = zeros(numSimulations, 1);
            ruinCount = 0;
            ruinThreshold = obj.InitialCapital * 0.5;
            
            for i = 1:numSimulations
                curve = equityCurves(:, i);
                finalEquities(i) = curve(end);
                
                % Drawdown
                peaks = cummax(curve);
                drawdowns = (peaks - curve) ./ peaks;
                maxDrawdowns(i) = max(drawdowns);
                
                % Ruin check
                if any(curve <= ruinThreshold)
                    ruinCount = ruinCount + 1;
                end
            end
            
            % Results
            sortedEquities = sort(finalEquities);
            p5 = sortedEquities(round(numSimulations * 0.05));
            p95 = sortedEquities(round(numSimulations * 0.95));
            medianEquity = median(sortedEquities);
            
            results = struct();
            results.MedianFinalEquity = medianEquity;
            results.Percentile_5th = p5;
            results.Percentile_95th = p95;
            results.ProbabilityOfRuin = (ruinCount / numSimulations) * 100;
            results.ExpectedMaxDrawdown = median(maxDrawdowns) * 100;
            results.WorstCaseDrawdown = max(maxDrawdowns) * 100;
            results.ExpectedAnnualReturn = ((medianEquity - obj.InitialCapital) / obj.InitialCapital) * 100;
            
            obj.printReport(results, numSimulations);
        end
        
        function printReport(~, results, iterations)
            fprintf('\n======================================================\n');
            fprintf('        MONTE CARLO ROBUSTNESS REPORT (%d runs)       \n', iterations);
            fprintf('======================================================\n');
            fprintf('Median Final Equity:   $%.2f\n', results.MedianFinalEquity);
            fprintf('90%% Confidence Int:    $%.2f - $%.2f\n', results.Percentile_5th, results.Percentile_95th);
            fprintf('Expected Ann Return:   %.2f%%\n', results.ExpectedAnnualReturn);
            fprintf('Expected Max DD:       %.2f%%\n', results.ExpectedMaxDrawdown);
            fprintf('Worst-Case DD:         %.2f%%\n', results.WorstCaseDrawdown);
            fprintf('Probability of Ruin:   %.2f%%\n', results.ProbabilityOfRuin);
            fprintf('======================================================\n');
        end
    end
end
