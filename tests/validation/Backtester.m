%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef Backtester < handle
%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
    % Backtester Evaluates the profitability and metrics of the AI model
    % over historical data. Simulates strict execution constraints.
    
    properties
        Model
        RiskEngine
        HistoricalData
        Predictions
    end
    
    methods
        function obj = Backtester(model, riskEngine, historicalData)
            obj.Model = model;
            obj.RiskEngine = riskEngine;
            obj.HistoricalData = historicalData;
        end
        
        function results = run(obj)
            Logger.info('Starting Historical Backtest with Production Models...');
            
            % 1. Load actual models and scaler
            mgr = ModelManager();
            [models, scaler, featureList, targetScaler] = mgr.loadArtifacts();
            
            % 2. Use Single Source of Truth for Data Prep
            [fullData, X, Y] = PipelineDataProcessor.prepareData(featureList);
            
            numRows = height(fullData);
            obj.Predictions = zeros(numRows, 1);
            
            equity = 10000;
            equityCurve = zeros(numRows, 1);
            equityCurve(1) = equity;
            
            winCount = 0;
            lossCount = 0;
            tradeCount = 0;
            
            % 3. Apply exact production scaling to entire dataset
            X_scaled = PipelineDataProcessor.scaleData(X, scaler);
            
            % Simulate step-by-step
            for i = 2:numRows-1
                currPrice = fullData.Close(i);
                atr = fullData.ATR_14(i);
                
                % Use pre-scaled features
                features_scaled = X_scaled(i, :);
                
                % Prediction
                predPrice = PipelineDataProcessor.predictEnsemble(models, features_scaled, targetScaler);
                obj.Predictions(i) = predPrice;
                
                % Risk evaluation
                [isValid, sl, tp] = obj.RiskEngine.evaluateTrade(currPrice, predPrice, atr);
                
                    if isValid
                        tradeCount = tradeCount + 1;
                        nextPrice = fullData.Close(i+1);
                    
                    % Simplified Execution Logic:
                    isLong = predPrice > currPrice;
                    
                    if isLong
                        if nextPrice >= tp
                            equity = equity + (tp - currPrice);
                            winCount = winCount + 1;
                        elseif nextPrice <= sl
                            equity = equity - (currPrice - sl);
                            lossCount = lossCount + 1;
                        else
                            % Closed at EOD
                            profit = nextPrice - currPrice;
                            equity = equity + profit;
                            if profit > 0
                                winCount = winCount + 1;
                            else
                                lossCount = lossCount + 1;
                            end
                        end
                    else
                        % Short
                        if nextPrice <= tp
                            equity = equity + (currPrice - tp);
                            winCount = winCount + 1;
                        elseif nextPrice >= sl
                            equity = equity - (sl - currPrice);
                            lossCount = lossCount + 1;
                        else
                            % Closed at EOD
                            profit = currPrice - nextPrice;
                            equity = equity + profit;
                            if profit > 0
                                winCount = winCount + 1;
                            else
                                lossCount = lossCount + 1;
                            end
                        end
                    end
                end
                
                equityCurve(i) = equity;
            end
            
            equityCurve(numRows) = equity;
            
            % Metrics
            results = struct();
            results.TotalTrades = tradeCount;
            results.FinalEquity = equity;
            results.ReturnPct = ((equity - 10000) / 10000) * 100;
            results.WinRate = (winCount / max(tradeCount, 1)) * 100;
            
            peaks = cummax(equityCurve);
            drawdowns = (peaks - equityCurve) ./ max(peaks, 1);
            results.MaxDrawdown = max(drawdowns) * 100;
            
            obj.printReport(results);
        end
        
        function printReport(~, results)
            fprintf('\n======================================================\n');
            fprintf('        HISTORICAL BACKTEST RESULTS (2015-2026)       \n');
            fprintf('======================================================\n');
            fprintf('Total Trades:    %d\n', results.TotalTrades);
            fprintf('Win Rate:        %.2f%%\n', results.WinRate);
            fprintf('Final Equity:    $%.2f\n', results.FinalEquity);
            fprintf('Return:          %.2f%%\n', results.ReturnPct);
            fprintf('Max Drawdown:    %.2f%%\n', results.MaxDrawdown);
            fprintf('======================================================\n');
        end
    end
end
