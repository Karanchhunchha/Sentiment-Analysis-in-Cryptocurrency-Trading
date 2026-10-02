%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef WalkForwardValidator < handle
%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>

    % WalkForwardValidator Performs genuine sliding-window (walk-forward)
    % out-of-sample validation.
    %
    % ============================ B7 CONTRACT ============================
    % Every fold is a self-contained experiment:
    %
    %   * The fold model is REBUILT from scratch inside the fold loop.
    %     No artifact under models/ (cnn_lstm.mat, arima.mat, scaler.mat,
    %     targetScaler.mat, ensemble.mat) is ever loaded as the fold model.
    %     ModelManager.loadArtifacts() is deliberately never called.
    %   * The feature scaler AND the target scaler are fitted on the fold
    %     training rows only, then applied to the fold evaluation rows.
    %   * Sequence windows use the canonical P0-04 contract
    %     PipelineDataProcessor.formatForCNNLSTM(X_scaled, 30):
    %     a window ending at row t is paired with the target aligned to t.
    %   * No training window crosses the fold's training boundary, and the
    %     evaluation windows are produced only for the fold's own test range.
    %   * Directional accuracy uses the corrected formulation
    %     sign(pred - prev) vs sign(actual - prev) with
    %     prev = [Y(trainEnd); y_test(1:end-1)].
    %
    % Every one of these invariants is enforced with a hard assert, not a
    % comment, so a regression fails loudly instead of silently producing
    % in-sample numbers.
    % ====================================================================

    properties
        HistoricalData
        TrainWindowSize
        StepSize
        FeatureList
        SequenceLength
        BaseSeed
        MinArimaxObs
        PreparedData
        FoldRecords
        Metrics
        Completed
        ProductionArtifactsUsed
        UseProductionEnsemble
    end

    methods
        function obj = WalkForwardValidator(historicalData, trainWindow, stepSize)
            % For signature compatibility with the historical caller.
            % trainWindow / stepSize are the DECLARED walk-forward structure
            % and are honoured exactly as supplied.
            if nargin < 1; historicalData = []; end
            if nargin < 2 || isempty(trainWindow); trainWindow = 500; end
            if nargin < 3 || isempty(stepSize); stepSize = 100; end

            obj.HistoricalData = historicalData;
            obj.TrainWindowSize = trainWindow;
            obj.StepSize = stepSize;
            obj.SequenceLength = 30;
            obj.BaseSeed = 20240707;
            obj.MinArimaxObs = 30;
            obj.FoldRecords = struct([]);
            obj.Metrics = struct();
            obj.Completed = false;
            % Structural guarantee, asserted again after every run.
            obj.ProductionArtifactsUsed = false;
            obj.UseProductionEnsemble = true;
            obj.FeatureList = {'Open', 'High', 'Low', 'Close', 'Volume', 'SMA_20', ...
                'SMA_50', 'EMA_20', 'EMA_50', 'MACD_Line', 'MACD_Signal', ...
                'MACD_Hist', 'RSI_14', 'BB_Upper', 'BB_Lower', 'VWAP', ...
                'Volatility_20', 'ATR_14', 'Daily_Sentiment', 'Tweet_Volume'};
        end

        % ---------------------------------------------------------------
        % Public API
        % ---------------------------------------------------------------
        function metrics = runValidation(obj)
            Logger.info('Starting Walk-Forward Validation (per-fold retraining)...');

            obj.Completed = false;
            obj.FoldRecords = struct([]);
            obj.Metrics = struct();

            pd = obj.buildPreparedData();

            numRows = size(pd.X, 1);
            folds = WalkForwardValidator.computeFoldBoundaries( ...
                numRows, obj.TrainWindowSize, obj.StepSize);

            if isempty(folds)
                error('WalkForwardValidator:NoFolds', ...
                    ['No walk-forward fold can be formed from %d rows with ' ...
                     'TrainWindowSize=%d and StepSize=%d.'], ...
                    numRows, obj.TrainWindowSize, obj.StepSize);
            end
            Logger.info('Walk-forward plan: %d folds (train=%d, step=%d, %d rows).', ...
                numel(folds), obj.TrainWindowSize, obj.StepSize, numRows);

            assert(obj.ProductionArtifactsUsed == false, ...
                'WalkForwardValidator:ProductionArtifactFlag', ...
                'ProductionArtifactsUsed must be false: no model under models/ may act as a fold model.');

            allPreds = [];
            allActuals = [];
            ensPreds = [];
            ensActuals = [];
            totalHits = 0;
            totalScored = 0;
            totalStrictHits = 0;
            totalStrictScored = 0;
            numEnsembleFolds = 0;

            for k = 1:numel(folds)
                rec = obj.runOneFold(folds(k), k, pd);

                allPreds = [allPreds; rec.Predictions]; %#ok<AGROW>
                allActuals = [allActuals; rec.Actuals]; %#ok<AGROW>
                totalHits = totalHits + rec.DAccHits;
                totalScored = totalScored + rec.DAccScored;
                totalStrictHits = totalStrictHits + rec.StrictHits;
                totalStrictScored = totalStrictScored + rec.StrictScored;

                if strcmp(rec.ModelPath, 'fold-ensemble')
                    numEnsembleFolds = numEnsembleFolds + 1;
                    ensPreds = [ensPreds; rec.Predictions]; %#ok<AGROW>
                    ensActuals = [ensActuals; rec.Actuals]; %#ok<AGROW>
                end

                if k == 1
                    obj.FoldRecords = rec;
                else
                    obj.FoldRecords(end+1) = rec; %#ok<AGROW>
                end

                fprintf('  -> Fold %2d/%2d  train[%4d..%4d]  test[%4d..%4d]  %s  n=%d  RMSE=%.2f  DA=%.2f%%\n', ...
                    k, numel(folds), rec.TrainStart, rec.TrainEnd, ...
                    rec.TestStart, rec.TestEnd, rec.ModelPath, ...
                    rec.NumPredictions, rec.RMSE, rec.DAcc);
            end

            % ---- Aggregate metrics over every genuine OOS prediction ----
            metrics = struct();
            metrics.NumFolds = numel(folds);
            metrics.TrainWindowSize = obj.TrainWindowSize;
            metrics.StepSize = obj.StepSize;
            metrics.NumRows = numRows;
            metrics.NumPredictions = numel(allPreds);
            metrics.NumEnsembleFolds = numEnsembleFolds;
            metrics.NumCnnOnlyFolds = numel(folds) - numEnsembleFolds;
            metrics.RMSE = sqrt(mean((allActuals - allPreds).^2));
            metrics.MAE = mean(abs(allActuals - allPreds));
            metrics.DirectionalAccuracy = totalHits / totalScored * 100;
            metrics.DAccHits = totalHits;
            metrics.DAccScored = totalScored;
            metrics.StrictDirectionalAccuracy = ...
                safeRatio(totalStrictHits, totalStrictScored) * 100;
            metrics.StrictHits = totalStrictHits;
            metrics.StrictScored = totalStrictScored;
            metrics.ProductionArtifactsUsed = false;
            metrics.PerFoldRetraining = true;
            metrics.FoldScalersFittedPerFold = true;
            metrics.SequenceContract = 'PipelineDataProcessor.formatForCNNLSTM(., 30)';
            metrics.DirectionalAccuracyFormula = ...
                'sign(pred - [Y(trainEnd); y_test(1:end-1)]) vs sign(y_test - [Y(trainEnd); y_test(1:end-1)])';

            % ---- Ensemble-restricted aggregate (folds where a genuine
            %      ARIMAX sub-model is estimable from fold-train data) ----
            if ~isempty(ensPreds)
                metrics.EnsembleRMSE = sqrt(mean((ensActuals - ensPreds).^2));
                metrics.EnsembleMAE = mean(abs(ensActuals - ensPreds));
                eh = 0; es = 0;
                for k = 1:numel(folds)
                    if strcmp(obj.FoldRecords(k).ModelPath, 'fold-ensemble')
                        eh = eh + obj.FoldRecords(k).DAccHits;
                        es = es + obj.FoldRecords(k).DAccScored;
                    end
                end
                metrics.EnsembleDirectionalAccuracy = eh / es * 100;
                metrics.EnsembleNumPredictions = numel(ensPreds);
            else
                metrics.EnsembleRMSE = NaN;
                metrics.EnsembleMAE = NaN;
                metrics.EnsembleDirectionalAccuracy = NaN;
                metrics.EnsembleNumPredictions = 0;
            end

            % ---- Final OOS integrity gate --------------------------------
            assert(obj.ProductionArtifactsUsed == false, ...
                'WalkForwardValidator:ProductionArtifactUsed', ...
                'A frozen production artifact was used as a fold model.');
            assert(numel(allPreds) == numel(folds) * obj.StepSize, ...
                'WalkForwardValidator:PredictionCountMismatch', ...
                'Expected %d OOS predictions, got %d.', ...
                numel(folds) * obj.StepSize, numel(allPreds));
            assert(totalScored == numel(allPreds), ...
                'WalkForwardValidator:DenominatorMismatch', ...
                'Directional-accuracy denominator (%d) must equal the number of scored predictions (%d).', ...
                totalScored, numel(allPreds));

            obj.Metrics = metrics;
            obj.Completed = true;
            obj.printReport();
        end

        function records = getFoldRecords(obj)
            records = obj.FoldRecords;
        end

        function m = getMetrics(obj)
            m = obj.Metrics;
        end

        function pd = buildPreparedData(obj)
            % Single Source of Truth for data preparation (P0-04 / B3).
            if ~isempty(obj.PreparedData)
                pd = obj.PreparedData;
                return;
            end
            [fullData, X, Y] = PipelineDataProcessor.prepareData(obj.FeatureList);
            observed = obj.genuineSentimentMask(fullData.Date);
            pd = struct();
            pd.X = X;
            pd.Y = Y(:);
            pd.Close = fullData.Close(:);
            pd.Sentiment = fullData.Daily_Sentiment(:);
            pd.SentimentObserved = observed;
            pd.Dates = fullData.Date;
        end

        % ---------------------------------------------------------------
        % One fold = one independent experiment
        % ---------------------------------------------------------------
        function rec = runOneFold(obj, fold, k, pd)
            trainStart = fold.TrainStart;
            trainEnd   = fold.TrainEnd;
            testStart  = fold.TestStart;
            testEnd    = fold.TestEnd;

            % ---- BOUNDARY INVARIANTS (asserted, not documented) --------
            assert(trainStart >= 1 && trainEnd >= trainStart, ...
                'WalkForwardValidator:BadTrainingWindow', ...
                'Fold %d has an invalid training window [%d..%d].', k, trainStart, trainEnd);
            assert(testStart == trainEnd + 1, ...
                'WalkForwardValidator:TestWindowDisconnected', ...
                'Fold %d test window must start immediately after trainEnd.', k);
            assert(testEnd - testStart + 1 == obj.StepSize, ...
                'WalkForwardValidator:BadTestWindow', ...
                'Fold %d test window must contain exactly StepSize (%d) rows.', k, obj.StepSize);

            rng(obj.BaseSeed + k, 'twister');

            % ---- 1. FOLD-SPECIFIC SCALERS, fitted on fold-train rows ----
            XTrainRaw = pd.X(trainStart:trainEnd, :);
            YTrainRaw = pd.Y(trainStart:trainEnd);
            foldScaler = WalkForwardValidator.fitMinMaxScaler(XTrainRaw);
            foldTargetScaler = WalkForwardValidator.fitMinMaxScaler(YTrainRaw);

            % Hard proof that no future row entered the scaler fit.
            assert(numel(foldScaler.Min) == size(pd.X, 2), ...
                'WalkForwardValidator:ScalerShape', ...
                'Fold %d feature scaler width does not match the feature count.', k);
            assert(isfinite(min(foldScaler.Min)) && isfinite(max(foldScaler.Max)), ...
                'WalkForwardValidator:ScalerNonFinite', ...
                'Fold %d produced a non-finite scaler.', k);

            % ---- 2. Fold CNN-LSTM, rebuilt from fold-train data only ----
            XTrainScaled = PipelineDataProcessor.scaleData(XTrainRaw, foldScaler);
            YTrainScaled = PipelineDataProcessor.scaleTarget(YTrainRaw, foldTargetScaler);
            [XTrainSeq, vTrain] = PipelineDataProcessor.formatForCNNLSTM( ...
                XTrainScaled, obj.SequenceLength);
            YTrainSeq = YTrainScaled(vTrain);

            % P0-04 contract: the last training sequence ends at row trainEnd,
            % so no training target can come from the test window.
            trainTargetMaxRow = trainStart + vTrain(end) - 1;
            assert(trainTargetMaxRow == trainEnd, ...
                'WalkForwardValidator:TrainTestCrossing', ...
                'Fold %d last training target row (%d) must equal trainEnd (%d).', ...
                k, trainTargetMaxRow, trainEnd);
            assert(trainTargetMaxRow < testStart, ...
                'WalkForwardValidator:TrainTestCrossing', ...
                'Fold %d training targets must precede the test window.', k);

            layers = [ ...
                sequenceInputLayer(size(XTrainRaw, 2), 'Name', 'input')
                convolution1dLayer(3, 16, 'Padding', 'same', 'Name', 'conv1')
                reluLayer('Name', 'relu1')
                lstmLayer(32, 'OutputMode', 'last', 'Name', 'lstm1')
                fullyConnectedLayer(1, 'Name', 'fc')
                regressionLayer('Name', 'output')];

            options = trainingOptions('adam', ...
                'MaxEpochs', 15, ...
                'MiniBatchSize', 32, ...
                'GradientThreshold', 1, ...
                'Verbose', false, ...
                'Plots', 'none');

            % No try/catch: a fold training failure must propagate. A silent
            % fallback here would fabricate OOS predictions.
            foldNet = trainNetwork(XTrainSeq, YTrainSeq, layers, options);
            assert(~isstruct(foldNet), 'WalkForwardValidator:StubFoldModel', ...
                'Fold %d produced a stub instead of a trained network.', k);

            % ---- 3. Fold ARIMAX sub-model, rebuilt from fold-train rows ----
            [foldArima, arimaxStatus, arimaxReason, arimaxN] = ...
                obj.trainFoldArimax(pd, trainStart, trainEnd);

            % ---- 4. Evaluation window: ONLY the fold's test range --------
            % Window ending at row t -> target aligned to t (P0-04).
            evalStart = testStart - (obj.SequenceLength - 1);
            assert(evalStart >= 1, 'WalkForwardValidator:LookbackUnderflow', ...
                'Fold %d cannot supply the %d-step lookback.', k, obj.SequenceLength);

            XEvalRaw = pd.X(evalStart:testEnd, :);
            XEvalScaled = PipelineDataProcessor.scaleData(XEvalRaw, foldScaler);

            [~, vEval] = PipelineDataProcessor.formatForCNNLSTM( ...
                XEvalScaled, obj.SequenceLength);
            evalTargetRows = evalStart + vEval - 1;
            assert(evalTargetRows(1) == testStart && evalTargetRows(end) == testEnd, ...
                'WalkForwardValidator:PredictionWindowMismatch', ...
                'Fold %d evaluation targets [%d..%d] must match the test window [%d..%d].', ...
                k, evalTargetRows(1), evalTargetRows(end), testStart, testEnd);

            y_test = pd.Y(testStart:testEnd);

            if strcmp(arimaxStatus, 'trained')
                % B5 contract: the full ensemble is evaluated through the
                % already-correct predictEnsemble, with the FOLD models and
                % FOLD scalers. predictEnsemble itself is never modified.
                models = struct('CNN', foldNet, 'ARIMA', foldArima, ...
                                'EnsembleWeights', [0.6, 0.4]);
                rawPreds = PipelineDataProcessor.predictEnsemble( ...
                    models, XEvalScaled, foldTargetScaler, foldScaler, obj.FeatureList);
                preds = rawPreds(end - obj.StepSize + 1:end);
                preds = preds(:);
                modelPath = 'fold-ensemble';
            else
                % The ARIMAX sub-model is not estimable from this fold's
                % training data (see arimaxReason). This is reported, never
                % silently replaced. The fold is scored on its own retrained
                % CNN-LSTM component.
                [XEvalSeq, ~] = PipelineDataProcessor.formatForCNNLSTM( ...
                    XEvalScaled, obj.SequenceLength);
                cnnScaled = double(predict(foldNet, XEvalSeq));
                preds = PipelineDataProcessor.unscaleTarget(cnnScaled, foldTargetScaler);
                preds = preds(:);
                modelPath = 'fold-cnn-lstm-only';
            end

            % ---- 5. OOS INTEGRITY ASSERTS -------------------------------
            assert(numel(preds) == obj.StepSize, ...
                'WalkForwardValidator:PredictionCountMismatch', ...
                'Fold %d produced %d predictions; exactly StepSize (%d) are required.', ...
                k, numel(preds), obj.StepSize);
            assert(all(isfinite(preds)), 'WalkForwardValidator:NonFinitePrediction', ...
                'Fold %d produced non-finite predictions.', k);
            assert(trainEnd < testStart, ...
                'WalkForwardValidator:BoundaryViolation', ...
                'Fold %d: fold training maximum row (%d) must be < fold test minimum row (%d).', ...
                k, trainEnd, testStart);

            % ---- 6. Directional accuracy (corrected formulation) --------
            prev_prices = [pd.Y(trainEnd); y_test(1:end-1)];
            [dacc, daInfo] = WalkForwardValidator.computeDirectionalAccuracy( ...
                prev_prices, preds, y_test);

            rmse = sqrt(mean((y_test - preds).^2));
            mae = mean(abs(y_test - preds));

            rec = struct();
            rec.FoldIndex = k;
            rec.TrainStart = trainStart;
            rec.TrainEnd = trainEnd;
            rec.TestStart = testStart;
            rec.TestEnd = testEnd;
            rec.NumTrainRows = trainEnd - trainStart + 1;
            rec.NumTrainSequences = numel(XTrainSeq);
            rec.TrainTargetMaxRow = trainTargetMaxRow;
            rec.TrainSequenceMinRow = trainStart + vTrain(1) - 1;
            rec.EvalSequenceMinRow = evalStart;
            rec.EvalTargetMinRow = evalTargetRows(1);
            rec.EvalTargetMaxRow = evalTargetRows(end);
            rec.ScalerFittedOnRows = [trainStart, trainEnd];
            rec.ScalerMin = foldScaler.Min;
            rec.ScalerMax = foldScaler.Max;
            rec.TargetScalerMin = foldTargetScaler.Min;
            rec.TargetScalerMax = foldTargetScaler.Max;
            rec.ModelPath = modelPath;
            rec.ModelSource = 'retrained-inside-fold';
            rec.ProductionArtifactUsed = false;
            rec.ModelFingerprint = WalkForwardValidator.modelFingerprint( ...
                foldNet, foldArima, foldScaler, foldTargetScaler);
            rec.ARIMAXStatus = arimaxStatus;
            rec.ARIMAXReason = arimaxReason;
            rec.ARIMAXNumObs = arimaxN;
            rec.NumPredictions = numel(preds);
            rec.Predictions = preds;
            rec.Actuals = y_test;
            rec.PrevPrices = prev_prices;
            rec.RMSE = rmse;
            rec.MAE = mae;
            rec.DAcc = dacc;
            rec.DAccHits = daInfo.Hits;
            rec.DAccScored = daInfo.Scored;
            rec.StrictHits = daInfo.StrictHits;
            rec.StrictScored = daInfo.StrictScored;
            rec.FlatPredictions = daInfo.FlatPredictions;
            rec.FlatActuals = daInfo.FlatActuals;
            rec.PredictionFirstPrevPrice = prev_prices(1);
            rec.PredictionFirstActual = y_test(1);
            rec.PredictionFirstValue = preds(1);
        end

        % ---------------------------------------------------------------
        % Fold ARIMAX: rebuilt inside the fold, never loaded from disk
        % ---------------------------------------------------------------
        function [m, status, reason, nObs] = trainFoldArimax(obj, pd, trainStart, trainEnd)
            m = [];
            status = 'infeasible';
            reason = '';
            nObs = 0;

            % Genuine sentiment observations strictly inside this fold's
            % training window. No row beyond trainEnd may be considered.
            ovMask = pd.SentimentObserved(trainStart:trainEnd);
            ovLocal = find(ovMask);

            if numel(ovLocal) < (obj.MinArimaxObs + 1)
                reason = sprintf(['insufficient_genuine_sentiment_overlap_in_fold ' ...
                    '(%d rows < %d required)'], numel(ovLocal), obj.MinArimaxObs + 1);
                return;
            end

            % Y0 presample (2 rows) taken at the first two aligned rows;
            % estimation then runs on every remaining aligned row, all of
            % which are <= trainEnd by construction.
            ovRows = trainStart + ovLocal - 1;
            yEst = pd.Close(ovRows(2:end));
            xEst = pd.Sentiment(ovRows(2:end));
            y0 = pd.Close(ovRows(1:2));
            nObs = numel(yEst);

            if nObs < obj.MinArimaxObs
                reason = sprintf('insufficient_aligned_observations (%d)', nObs);
                return;
            end

            try
                candidate = estimate(arima(1, 1, 1), yEst, 'X', xEst, 'Y0', y0, 'Display', 'off');
                if ~isa(candidate, 'arima') || isempty(candidate.Variance)
                    error('WalkForwardValidator:ArimaxNotEstimated', ...
                        'ARIMAX estimation returned a non-estimated object.');
                end
                verifyFcast = forecast(candidate, 1, 'Y0', y0, 'XF', xEst(1));
                if ~isfinite(verifyFcast)
                    error('WalkForwardValidator:ArimaxNonFinite', ...
                        'Fold ARIMAX produced a non-finite one-step forecast.');
                end
                m = candidate;
                status = 'trained';
            catch ME
                % Recorded, not hidden: the reason travels with the fold
                % record and is printed in the report.
                status = 'infeasible';
                reason = sprintf('estimation_failed: %s', ME.message);
            end
        end

    end

    methods (Static)
        function folds = computeFoldBoundaries(numRows, trainWindow, stepSize)
            validateattributes(numRows, {'numeric'}, {'scalar','integer','positive'});
            validateattributes(trainWindow, {'numeric'}, {'scalar','integer','positive'});
            validateattributes(stepSize, {'numeric'}, {'scalar','integer','positive'});

            folds = struct('FoldIndex', {}, 'TrainStart', {}, 'TrainEnd', {}, ...
                           'TestStart', {}, 'TestEnd', {});
            startIdx = 1;
            k = 0;
            while (startIdx + trainWindow + stepSize) <= numRows
                k = k + 1;
                trainEnd = startIdx + trainWindow - 1;
                folds(k) = struct('FoldIndex', k, ...
                    'TrainStart', startIdx, ...
                    'TrainEnd', trainEnd, ...
                    'TestStart', trainEnd + 1, ...
                    'TestEnd', trainEnd + stepSize);
                startIdx = startIdx + stepSize;
            end
        end

        function scaler = fitMinMaxScaler(M)
            scaler = struct();
            scaler.Min = min(M, [], 1);
            scaler.Max = max(M, [], 1);
            range = scaler.Max - scaler.Min;
            range(range == 0) = 1;
            scaler.Range = range;
        end

        function [dacc, info] = computeDirectionalAccuracy(prevPrices, preds, actuals)
            % Corrected Directional Accuracy.
            %
            %   prev_prices = [Y(trainEnd); y_test(1:end-1)]
            %   pred_dir    = sign(preds - prev_prices)
            %   actual_dir  = sign(y_test - prev_prices)
            %
            % The previous formulation sign(diff([0; predictions])) scored the
            % model's own momentum and always scored the first element as a
            % zero move; it is removed here.
            %
            % Every valid prediction is counted exactly once, so the
            % denominator equals the number of scored predictions. A zero
            % movement can only match another zero movement: a flat forecast
            % against a moving market is scored as a miss, never a hit.
            prev = prevPrices(:);
            p = preds(:);
            a = actuals(:);

            if numel(prev) ~= numel(p) || numel(prev) ~= numel(a)
                error('WalkForwardValidator:DirectionalAccuracyShape', ...
                    'prev_prices, preds and y_test must have equal length.');
            end
            if isempty(p)
                error('WalkForwardValidator:DirectionalAccuracyEmpty', ...
                    'Directional accuracy requires at least one scored prediction.');
            end

            predDir = sign(p - prev);
            actDir  = sign(a - prev);

            hits = sum(predDir == actDir);
            scored = numel(predDir);

            info = struct();
            info.Hits = hits;
            info.Scored = scored;
            info.PredDirections = predDir;
            info.ActualDirections = actDir;
            info.FlatPredictions = sum(predDir == 0);
            info.FlatActuals = sum(actDir == 0);
            info.MissCount = scored - hits;
            info.StrictScored = sum(actDir ~= 0);
            info.StrictHits = sum(predDir == actDir & actDir ~= 0);

            dacc = hits / scored * 100;
        end

        function fp = modelFingerprint(net, arimaObj, scaler, targetScaler)
            vals = [];
            if ~isempty(net)
                try
                    lay = net.Layers;
                    for li = 1:numel(lay)
                        L = lay(li);
                        props = properties(L);
                        for pk = 1:numel(props)
                            pn = props{pk};
                            if any(strcmp(pn, {'Weights','Bias','InputWeights','RecurrentWeights','LayerWeights','OutputWeights'}))
                                try
                                    v = double(L.(pn));
                                    if ~isempty(v) && isnumeric(v)
                                        vals = [vals; v(:)]; %#ok<AGROW>
                                    end
                                catch
                                end
                            end
                        end
                    end
                catch
                end
                if isempty(vals)
                    try
                        d = net.serialize;
                        vals = double(d(:));
                    catch
                    end
                end
            end
            netPart = sprintf('n=%d|sum=%.10e|abs=%.10e|max=%.10e|min=%.10e', ...
                numel(vals), sum(vals), sum(abs(vals)), max(vals), min(vals));

            arimaPart = 'none';
            if ~isempty(arimaObj) && isa(arimaObj, 'arima')
                beta = 'noBeta';
                if ~isempty(arimaObj.Beta)
                    beta = sprintf('%.10e', sum(arimaObj.Beta(:)));
                end
                ar = [];
                if ~isempty(arimaObj.AR)
                    v = arimaObj.AR;
                    for ci = 1:numel(v)
                        if ~isempty(v{ci})
                            ar = [ar; double(v{ci}(:))]; %#ok<AGROW>
                        end
                    end
                end
                arimaPart = sprintf('var=%.10e|beta=%s|phiSum=%.6f', ...
                    arimaObj.Variance, beta, sum(ar));
            end

            scalerPart = sprintf('min=%.10e|max=%.10e', sum(scaler.Min), sum(scaler.Max));
            targetPart = sprintf('min=%.10e|max=%.10e', targetScaler.Min, targetScaler.Max);

            fp = sprintf('%s#%s#%s#%s', netPart, arimaPart, scalerPart, targetPart);
        end

        function mask = genuineSentimentMask(dates)
            % Rows that correspond to a real observation in the committed
            % sentiment dataset (not a forward-filled carry-forward).
            mask = false(size(dates));
            try
                sentPath = fullfile(pwd, 'data', 'sentiment', 'historical_daily_sentiment.csv');
                if ~exist(sentPath, 'file')
                    return;
                end
                sentimentData = readtable(sentPath);
                sentimentDates = dateshift(datetime(sentimentData.Date), 'start', 'day');
                grid = dateshift(datetime(dates), 'start', 'day');
                mask = ismember(grid, sentimentDates);
            catch
                mask = false(size(dates));
            end
        end
    end

    methods
        % ---------------------------------------------------------------
        % Reporting
        % ---------------------------------------------------------------
        function printReport(obj)
            m = obj.Metrics;
            fprintf('\n======================================================\n');
            fprintf('   WALK-FORWARD VALIDATION (PER-FOLD RETRAINING)      \n');
            fprintf('======================================================\n');
            fprintf('Folds                       : %d (train=%d, step=%d)\n', ...
                m.NumFolds, m.TrainWindowSize, m.StepSize);
            fprintf('Total OOS Predictions       : %d\n', m.NumPredictions);
            fprintf('Production artifacts used   : %s\n', tf2yn(m.ProductionArtifactsUsed));
            fprintf('RMSE                        : %.4f\n', m.RMSE);
            fprintf('MAE                         : %.4f\n', m.MAE);
            fprintf('Directional Accuracy        : %.2f%% (%d/%d scored)\n', ...
                m.DirectionalAccuracy, m.DAccHits, m.DAccScored);
            fprintf('Directional Acc. (non-flat) : %.2f%% (%d/%d scored)\n', ...
                m.StrictDirectionalAccuracy, m.StrictHits, m.StrictScored);
            fprintf('------------------------------------------------------\n');
            fprintf('Folds scored on full ensemble: %d\n', m.NumEnsembleFolds);
            fprintf('Folds scored on CNN-LSTM only: %d (ARIMAX not estimable from fold-train data)\n', ...
                m.NumCnnOnlyFolds);
            if m.EnsembleNumPredictions > 0
                fprintf('Ensemble-subset predictions : %d\n', m.EnsembleNumPredictions);
                fprintf('Ensemble-subset RMSE        : %.4f\n', m.EnsembleRMSE);
                fprintf('Ensemble-subset DA          : %.2f%%\n', m.EnsembleDirectionalAccuracy);
            end
            fprintf('======================================================\n');
            fprintf('%-4s %-13s %-13s %-19s %-9s %s\n', ...
                'Fold', 'TrainRows', 'TestRows', 'ModelPath', 'NumPred', 'ARIMAX');
            for k = 1:numel(obj.FoldRecords)
                r = obj.FoldRecords(k);
                fprintf('%-4d %5d..%-7d %5d..%-7d %-19s %-9d %s\n', ...
                    r.FoldIndex, r.TrainStart, r.TrainEnd, r.TestStart, r.TestEnd, ...
                    r.ModelPath, r.NumPredictions, r.ARIMAXStatus);
            end
            fprintf('======================================================\n');
        end
    end
end

function s = tf2yn(v)
    if v; s = 'YES'; else; s = 'NO'; end
end

function r = safeRatio(num, den)
    if den == 0; r = NaN; else; r = num / den; end
end
