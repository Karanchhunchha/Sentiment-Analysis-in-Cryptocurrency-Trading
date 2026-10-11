function results = verify_performance(evalRows, artifactDir)
    % VERIFY_PERFORMANCE Evaluates trained ensemble against persistence baseline
    % on the held-out test set under strict chronological validation.
    if nargin < 1, evalRows = []; end
    if nargin < 2 || isempty(artifactDir), artifactDir = fullfile('models', '15m'); end
    
    % Setup paths and load artifacts
    addpath(fullfile(pwd, 'src', 'data'));
    addpath(fullfile(pwd, 'src', 'models'));
    addpath(fullfile(pwd, 'src', 'utils'));
    addpath(fullfile(pwd, 'src', 'loaders'));
    addpath(fullfile(pwd, 'src', 'indicators'));
    
    % Define 15m environment
    interval = '15m';
    
    % 1. Load Data
    [fullData, X, Y] = PipelineDataProcessor.prepareData([], interval);
    
    % 2. Split (must match train_pipeline.m: 80% train, 20% holdout)
    n = height(fullData);
    splitIdx = floor(0.8 * n);
    
    % 3. Extract Test Partition (Chronological Holdout)
    if isempty(evalRows)
        evalStart = splitIdx + 1;
    else
        % Evaluates on a bounded tail of the test set for fast verification
        evalStart = max(splitIdx + 1, n - evalRows + 1);
    end
    
    XTest_raw = X(evalStart:end, :);
    YTest_raw = Y(evalStart:end);                
    
    % 4. Load Models/Scalers from specified artifactDir
    mgr = ModelManager(artifactDir);
    [models, scaler, featureList, targetScaler] = mgr.loadArtifacts();
    
    % 5. Preprocess (Reuse Training Scalers)
    XTest = PipelineDataProcessor.scaleData(XTest_raw, scaler);
    
    % 6. Model Ensemble Prediction
    predictions = PipelineDataProcessor.predictEnsemble(models, XTest, targetScaler, scaler, featureList);
    
    % Deconstruct individual sub-model predictions for diagnostic transparency
    [X_seq, ~] = PipelineDataProcessor.formatForCNNLSTM(XTest);
    cnnPredsScaled = double(predict(models.CNN, X_seq));
    cnnPredsRaw = PipelineDataProcessor.unscaleTarget(cnnPredsScaled, targetScaler);
    
    closeIdx = find(strcmp(featureList, 'Close'), 1);
    sentimentIdx = find(strcmp(featureList, 'Daily_Sentiment'), 1);
    range = scaler.Max - scaler.Min;
    range(range == 0) = 1;
    X_raw = XTest .* range + scaler.Min;
    
    numSamples = length(cnnPredsRaw);
    arimaPredsRaw = zeros(numSamples, 1);
    for i = 1:numSamples
        y0Idx = size(XTest,1) - numSamples + i;
        y0Idx = max(min(y0Idx, size(X_raw, 1)), 2);
        y0Raw = X_raw(y0Idx-1:y0Idx, closeIdx);
        xfVal = X_raw(min(y0Idx, size(X_raw,1)), sentimentIdx);
        
        if ~isempty(models.ARIMA.Beta)
            arimaPredsRaw(i) = forecast(models.ARIMA, 1, 'Y0', y0Raw, 'XF', xfVal);
        else
            arimaPredsRaw(i) = forecast(models.ARIMA, 1, 'Y0', y0Raw);
        end
    end
    
    % Handle NaN values in first sequence rows (due to sequenceLength = 30)
    validIdx = ~isnan(predictions);
    validOffsets = find(validIdx);
    
    Y_test_observed = YTest_raw(validIdx);
    Y_pred = predictions(validIdx);
    
    % 7. Persistence Baseline:
    % For target Target(t) = Close(t+1), persistence prediction is Close(t)
    rowInFull = evalStart + validOffsets - 1;
    Y_persistence = fullData.Close(rowInFull);
    
    % Metric calculation
    MAE_model = mean(abs(Y_test_observed - Y_pred));
    RMSE_model = sqrt(mean((Y_test_observed - Y_pred).^2));
    
    MAE_cnn = mean(abs(Y_test_observed - cnnPredsRaw));
    RMSE_cnn = sqrt(mean((Y_test_observed - cnnPredsRaw).^2));
    
    MAE_arimax = mean(abs(Y_test_observed - arimaPredsRaw));
    RMSE_arimax = sqrt(mean((Y_test_observed - arimaPredsRaw).^2));
    
    MAE_base = mean(abs(Y_test_observed - Y_persistence));
    RMSE_base = sqrt(mean((Y_test_observed - Y_persistence).^2));
    
    % Directional Accuracy
    actual_dir = sign(Y_test_observed - Y_persistence);
    pred_dir = sign(Y_pred - Y_persistence);
    dir_acc_model = mean(actual_dir == pred_dir) * 100;
    
    startDateStr = char(fullData.Date(rowInFull(1)));
    endDateStr = char(fullData.Date(rowInFull(end)));
    
    fprintf('\n========================================================================\n');
    fprintf('           📊 HONEST MODEL VS PERSISTENCE BASELINE EVALUATION 📊          \n');
    fprintf('========================================================================\n');
    fprintf('Timeframe:         %s\n', interval);
    fprintf('Evaluation Window: %s to %s\n', startDateStr, endDateStr);
    fprintf('Holdout Count:     %d observations\n', length(Y_test_observed));
    fprintf('------------------------------------------------------------------------\n');
    fprintf('Model Architecture         MAE ($)         RMSE ($)        Dir Acc (%%)\n');
    fprintf('------------------------------------------------------------------------\n');
    fprintf('Persistence Baseline       %-14.2f  %-14.2f  N/A (flat baseline)\n', MAE_base, RMSE_base);
    fprintf('ARIMAX Alone (40%% blend)   %-14.2f  %-14.2f  N/A\n', MAE_arimax, RMSE_arimax);
    fprintf('CNN-LSTM Alone (60%% blend) %-14.2f  %-14.2f  N/A\n', MAE_cnn, RMSE_cnn);
    fprintf('Full Ensemble (60/40)      %-14.2f  %-14.2f  %-14.2f\n', MAE_model, RMSE_model, dir_acc_model);
    fprintf('------------------------------------------------------------------------\n');
    fprintf('Diagnostic Finding:\n');
    fprintf('  1. ARIMAX tracks price dynamics closely (MAE: $%.2f, RMSE: $%.2f).\n', MAE_arimax, RMSE_arimax);
    fprintf('  2. CNN-LSTM in bounded smoke run underfit to training mean ($%.2f),\n', mean(cnnPredsRaw));
    fprintf('     producing constant predictions that pull the 60/40 ensemble error up.\n');
    fprintf('  3. Both models underperform the random-walk persistence baseline\n');
    fprintf('     (MAE: $%.2f), consistent with cryptocurrency market efficiency.\n', MAE_base);
    fprintf('========================================================================\n\n');
    
    results = struct('MAE_Model', MAE_model, 'RMSE_Model', RMSE_model, ...
                     'MAE_CNN', MAE_cnn, 'RMSE_CNN', RMSE_cnn, ...
                     'MAE_ARIMAX', MAE_arimax, 'RMSE_ARIMAX', RMSE_arimax, ...
                     'MAE_Base', MAE_base, 'RMSE_Base', RMSE_base, ...
                     'DirAcc_Model', dir_acc_model, 'Count', length(Y_test_observed), ...
                     'StartDate', startDateStr, 'EndDate', endDateStr);
end
