%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef Backtester < handle
    properties
        InitialEquity = 10000
        RiskFraction = 0.01
        MaxLeverage = 2.0
        FeeRate = 0.001
        SlippageRate = 0.0005
        SequenceLength = 30
        TrainWindowSize = 500
        StepSize = 100
    end
properties
        Model
        RiskEngine
        HistoricalData
        Predictions
        TradeLog
        EquityCurve
        FoldMetrics
    end
    
    methods
        function obj = Backtester(model, riskEngine, historicalData)
            obj.Model = model;
            obj.RiskEngine = riskEngine;
            obj.HistoricalData = historicalData;
        end
        
        function results = run(obj)
            Logger.info('Starting OOS Historical Backtest (B08)...');

            %mgr = ModelManager();
            %[models, scaler, featureList, targetScaler] = mgr.loadArtifacts();
            % Load featureList only (no models)
            featureList = {'Open', 'High', 'Low', 'Close', 'Volume', 'SMA_20', ...
                'SMA_50', 'EMA_20', 'EMA_50', 'MACD_Line', 'MACD_Signal', ...
                'MACD_Hist', 'RSI_14', 'BB_Upper', 'BB_Lower', 'VWAP', ...
                'Volatility_20', 'ATR_14', 'Daily_Sentiment', 'Tweet_Volume'};

            [fullData, X, Y] = PipelineDataProcessor.prepareData(featureList);
            numRows = height(fullData);
            obj.Predictions = zeros(numRows, 1);

            if ~isfinite(obj.InitialEquity) || obj.InitialEquity <= 0
                error('Backtester:BadInitialEquity','InitialEquity must be positive.');
            end
            if obj.RiskFraction <= 0 || obj.RiskFraction >= 1
                error('Backtester:BadRiskFraction','RiskFraction must be in (0,1).');
            end
            if obj.MaxLeverage <= 0
                error('Backtester:BadMaxLeverage','MaxLeverage must be positive.');
            end
            if obj.FeeRate < 0 || obj.SlippageRate < 0
                error('Backtester:BadExecutionRates','FeeRate and SlippageRate must be non-negative.');
            end
            if ~ismember('High', fullData.Properties.VariableNames) || ~ismember('Low', fullData.Properties.VariableNames)
                error('Backtester:MissingOHLC','fullData must include High and Low columns for TP/SL ambiguity handling.');
            end
            if ~ismember('Date', fullData.Properties.VariableNames)
                error('Backtester:MissingDate','fullData must include Date for trade log timing.');
            end

            folds = WalkForwardValidator.computeFoldBoundaries(numRows, obj.TrainWindowSize, obj.StepSize);
            if isempty(folds)
                error('Backtester:NoFolds','No walk-forward folds possible with TrainWindowSize=%d StepSize=%d for %d rows.', obj.TrainWindowSize, obj.StepSize, numRows);
            end

            equity = obj.InitialEquity;
            equityCurve = zeros(numRows, 1);
            equityCurve(1) = equity;

            winCount = 0;
            lossCount = 0;
            tradeCount = 0;

            allTrades = table();

            seqLen = obj.SequenceLength;

            for k = 1:numel(folds)
                f = folds(k);

                foldScaler = WalkForwardValidator.fitMinMaxScaler(X(f.TrainStart:f.TrainEnd, :));
                foldTargetScaler = WalkForwardValidator.fitMinMaxScaler(Y(f.TrainStart:f.TrainEnd));

                % Fold-specific retraining (B07 methodology)
                XTrainRaw = X(f.TrainStart:f.TrainEnd, :);
                YTrainRaw = Y(f.TrainStart:f.TrainEnd);
                XTrainScaled = PipelineDataProcessor.scaleData(XTrainRaw, foldScaler);
                YTrainScaled = PipelineDataProcessor.scaleTarget(YTrainRaw, foldTargetScaler);
                [XTrainSeq, vTrain] = PipelineDataProcessor.formatForCNNLSTM(XTrainScaled, obj.SequenceLength);
                YTrainSeq = YTrainScaled(vTrain);

                layers = [ ...
                    sequenceInputLayer(size(XTrainRaw, 2), 'Name', 'input')
                    convolution1dLayer(3, 16, 'Padding', 'same', 'Name', 'conv1')
                    reluLayer('Name', 'relu1')
                    lstmLayer(32, 'OutputMode', 'last', 'Name', 'lstm1')
                    fullyConnectedLayer(1, 'Name', 'fc')
                    regressionLayer('Name', 'output')];
                options = trainingOptions('adam', 'MaxEpochs', 15, 'MiniBatchSize', 32, 'GradientThreshold', 1, 'Verbose', false, 'Plots', 'none');
                foldNet = trainNetwork(XTrainSeq, YTrainSeq, layers, options);

                % Arimax is hard to reimplement quickly; reusing WalkForwardValidator's logic is best.
                wf = WalkForwardValidator([], obj.TrainWindowSize, obj.StepSize);
                % Try to use WalkForwardValidator's arimax training if possible:
                try
                    pd = wf.buildPreparedData();
                    [foldArima, arimaxStatus] = wf.trainFoldArimax(pd, f.TrainStart, f.TrainEnd);
                    if strcmp(arimaxStatus, 'trained')
                        models = struct('CNN', foldNet, 'ARIMA', foldArima, 'EnsembleWeights', [0.6, 0.4]);
                    else
                        models = struct('CNN', foldNet, 'ARIMA', [], 'EnsembleWeights', [1, 0]);
                    end
                catch
                    models = struct('CNN', foldNet, 'ARIMA', [], 'EnsembleWeights', [1, 0]);
                end

                XScaled = PipelineDataProcessor.scaleData(X, foldScaler);

                for i = max(f.TestStart, seqLen):min(f.TestEnd, numRows-1)
                    currPrice = fullData.Close(i);
                    atr = fullData.ATR_14(i);

                    features_scaled = XScaled(i-seqLen+1:i, :);
                    
                    if ~isempty(models.ARIMA)
                        preds = PipelineDataProcessor.predictEnsemble(models, features_scaled, foldTargetScaler, foldScaler, featureList);
                        predPrice = preds(end);
                    else
                        [X_seq, ~] = PipelineDataProcessor.formatForCNNLSTM(features_scaled, obj.SequenceLength);
                        cnnScaled = double(predict(models.CNN, X_seq));
                        preds = PipelineDataProcessor.unscaleTarget(cnnScaled, foldTargetScaler);
                        predPrice = preds(end);
                    end
                    
                    obj.Predictions(i) = predPrice;

                    [isValid, sl, tp] = obj.RiskEngine.evaluateTrade(currPrice, predPrice, atr);
                    if ~isValid
                        continue;
                    end

                    isLong = predPrice > currPrice;

                    exitIdx = i + 1;
                    if exitIdx > numRows
                        break;
                    end

                    entryTime = fullData.Date(i);
                    exitTime = fullData.Date(exitIdx);

                    stopDistance = abs(currPrice - sl);
                    if ~isfinite(stopDistance) || stopDistance <= 0
                        continue;
                    end

                    riskCapital = equity * obj.RiskFraction;
                    positionUnits = riskCapital / stopDistance;
                    if ~isfinite(positionUnits) || positionUnits <= 0
                        continue;
                    end

                    entryNotional = abs(currPrice * positionUnits);
                    maxNotional = obj.MaxLeverage * equity;
                    if entryNotional > maxNotional
                        positionUnits = (maxNotional / max(currPrice, eps));
                        if ~isfinite(positionUnits) || positionUnits <= 0
                            continue;
                        end
                        entryNotional = abs(currPrice * positionUnits);
                    end

                    entryExecPrice = currPrice;
                    exitTheoreticalPrice = fullData.Close(exitIdx);
                    execSlippageEntry = obj.SlippageRate * currPrice;
                    execSlippageExit = obj.SlippageRate * exitTheoreticalPrice;

                    if isLong
                        entryExecPrice = currPrice + execSlippageEntry;
                        exitExecPrice  = exitTheoreticalPrice - execSlippageExit;
                    else
                        entryExecPrice = currPrice - execSlippageEntry;
                        exitExecPrice  = exitTheoreticalPrice + execSlippageExit;
                    end

                    entryFee = entryNotional * obj.FeeRate;
                    
                    tradeGrossPnL = 0;
                    exitReason = 'EOD_CLOSE';
                    stopLossPrice = sl;
                    takeProfitPrice = tp;

                    highN = fullData.High(exitIdx);
                    lowN  = fullData.Low(exitIdx);

                    hitSL = false;
                    hitTP = false;

                    if isLong
                        hitSL = lowN <= sl;
                        hitTP = highN >= tp;
                        if hitSL && hitTP
                            exitReason = 'CONSERVATIVE_SL_FIRST';
                            exitTheoreticalPrice = sl;
                        elseif hitTP
                            exitReason = 'TAKE_PROFIT';
                            exitTheoreticalPrice = tp;
                        elseif hitSL
                            exitReason = 'STOP_LOSS';
                            exitTheoreticalPrice = sl;
                        end
                        % Adverse slippage for long exit: receive less
                        exitExecPrice = exitTheoreticalPrice - obj.SlippageRate * exitTheoreticalPrice;
                    else
                        hitSL = highN >= sl;
                        hitTP = lowN <= tp;
                        if hitSL && hitTP
                            exitReason = 'CONSERVATIVE_SL_FIRST';
                            exitTheoreticalPrice = sl;
                        elseif hitTP
                            exitReason = 'TAKE_PROFIT';
                            exitTheoreticalPrice = tp;
                        elseif hitSL
                            exitReason = 'STOP_LOSS';
                            exitTheoreticalPrice = sl;
                        end
                        % Adverse slippage for short exit: pay more
                        exitExecPrice = exitTheoreticalPrice + obj.SlippageRate * exitTheoreticalPrice;
                    end

                    entryFeePaid = entryFee;
                    exitNotional = abs(exitExecPrice * positionUnits);
                    exitFee = exitNotional * obj.FeeRate;

                    if isLong
                        tradeGrossPnL = (exitExecPrice - entryExecPrice) * positionUnits;
                    else
                        tradeGrossPnL = (entryExecPrice - exitExecPrice) * positionUnits;
                    end

                    tradeNetPnL = tradeGrossPnL - entryFeePaid - exitFee;

                    equityBefore = equity;
                    equity = equity + tradeNetPnL;

                    if equity <= 0
                        equity = 0;
                    end

                    equityCurve(exitIdx) = equity;

                    tradeCount = tradeCount + 1;
                    if tradeNetPnL > 0
                        winCount = winCount + 1;
                    else
                        lossCount = lossCount + 1;
                    end

                    newRow = {entryTime, exitTime, isLong*1 + (~isLong)*(-1), currPrice, exitTheoreticalPrice, positionUnits, entryNotional, exitNotional, entryFeePaid, exitFee, abs(execSlippageEntry) + abs(execSlippageExit), tradeGrossPnL, tradeNetPnL, equityBefore, equity, stopLossPrice, takeProfitPrice, exitReason};

                    if isempty(allTrades)
                        allTrades = cell2table(newRow, 'VariableNames', {'EntryTime','ExitTime','Direction','EntryPrice','ExitPrice','PositionUnits','EntryNotional','ExitNotional','EntryFee','ExitFee','Slippage','GrossPnL','NetPnL','EquityBefore','EquityAfter','StopLoss','TakeProfit','ExitReason'});
                    else
                        allTrades = [allTrades; newRow]; %#ok<AGROW>
                    end

                end
            end

            obj.TradeLog = allTrades;
            obj.EquityCurve = equityCurve;

            % Forward-fill equity curve to carry equity between trade exits
            lastEq = equityCurve(1);
            for idx = 2:numel(equityCurve)
                if equityCurve(idx) ~= 0
                    lastEq = equityCurve(idx);
                else
                    equityCurve(idx) = lastEq;
                end
            end
            obj.EquityCurve = equityCurve;

            peaks = cummax(equityCurve);
            drawdowns = (peaks - equityCurve) ./ max(peaks, 1);

            results = struct();
            results.TotalTrades = tradeCount;
            results.FinalEquity = equity;
            results.ReturnPct = ((equity - obj.InitialEquity) / obj.InitialEquity) * 100;
            results.WinRate = (winCount / max(tradeCount, 1)) * 100;
            results.MaxDrawdown = max(drawdowns) * 100;
            results.EquityCurve = equityCurve;
            results.TradeLog = allTrades;

            % Portfolio risk metrics
            riskResults = RiskMetricsCalculator.calculateAll(equityCurve);
            
            results.SharpeRatio = riskResults.SharpeRatio;
            results.SortinoRatio = riskResults.SortinoRatio;
            results.VaR_95 = riskResults.VaR_95;
            results.CVaR_95 = riskResults.CVaR_95;
            results.MaxDrawdown = riskResults.MaxDrawdown;

            results.DateRange = sprintf('%04d-%04d', year(fullData.Date(1)), year(fullData.Date(end)));
            obj.printReport(results);
        end

        function printReport(~, results)
            fprintf('\n======================================================\n');
            fprintf('        HISTORICAL BACKTEST RESULTS (%s)       \n', results.DateRange);
            fprintf('======================================================\n');
            fprintf('Total Trades:    %d\n', results.TotalTrades);
            fprintf('Win Rate:        %.2f%%\n', results.WinRate);
            fprintf('Final Equity:    $%.2f\n', results.FinalEquity);
            fprintf('Return:          %.2f%%\n', results.ReturnPct);
            fprintf('Max Drawdown:    %.2f%%\n', results.MaxDrawdown);
            fprintf('Sharpe Ratio:    %.3f\n', results.SharpeRatio);
            fprintf('Sortino Ratio:   %.3f\n', results.SortinoRatio);
            fprintf('VaR (95%%):       %.3f%%\n', results.VaR_95 * 100);
            fprintf('CVaR (95%%):      %.3f%%\n', results.CVaR_95 * 100);
            fprintf('======================================================\n');
        end
    end
end
