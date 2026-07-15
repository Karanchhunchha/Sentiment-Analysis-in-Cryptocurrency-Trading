%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef MonteCarloSimulator < handle
    % MonteCarloSimulator Evaluates strategy robustness by running thousands
    % of randomized simulations based on historical trade distribution.
    % Computes Probability of Ruin, Expected Annual Return, and Drawdowns.
    
    properties
        WinRate
        AvgWin
        AvgLoss
        InitialCapital
    end
    
    methods
        function obj = MonteCarloSimulator(winRate, avgWinPercent, avgLossPercent, initialCapital)
            if nargin < 4; initialCapital = 10000; end
            
            obj.WinRate = winRate;
            obj.AvgWin = avgWinPercent;
            obj.AvgLoss = avgLossPercent;
            obj.InitialCapital = initialCapital;
        end
        
        function results = runSimulations(obj, numSimulations, tradesPerYear)
            if nargin < 2; numSimulations = 10000; end
            if nargin < 3; tradesPerYear = 252; end % Approx trading days
            
            Logger.info(sprintf('Running Monte Carlo Simulator (%d iterations)...', numSimulations));
            
            finalEquities = zeros(numSimulations, 1);
            maxDrawdowns = zeros(numSimulations, 1);
            ruinCount = 0;
            ruinThreshold = obj.InitialCapital * 0.5; % 50% loss considered ruin
            
            % Vectorized simulation for extreme performance
            % Generate random numbers: < WinRate = Win, else Loss
            randomMatrix = rand(tradesPerYear, numSimulations);
            winMatrix = randomMatrix <= obj.WinRate;
            
            % Assign returns: AvgWin for wins, AvgLoss for losses
            % (Assuming fixed percentage for simplified robust MC)
            returnMatrix = zeros(tradesPerYear, numSimulations);
            returnMatrix(winMatrix) = obj.AvgWin;
            returnMatrix(~winMatrix) = obj.AvgLoss; % Note: AvgLoss should be negative
            
            % Calculate cumulative equity curves
            % Equity(t) = Equity(t-1) * (1 + Return)
            growthMatrix = 1 + returnMatrix;
            equityCurves = obj.InitialCapital * cumprod(growthMatrix, 1);
            
            % Process results
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
            
            % Calculate Confidence Intervals (5th and 95th percentiles)
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
