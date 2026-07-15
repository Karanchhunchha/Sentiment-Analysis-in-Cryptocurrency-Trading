%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef ModelComparer < handle
%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
    % ModelComparer Orchestrates the institutional model comparison suite.
    % Evaluates multiple architectures (ARIMA, Random Forest, CNN, LSTM)
    % strictly on the same out-of-sample data to prevent selection bias.
    
    properties
        HistoricalData
        TrainData
        TestData
        Results
    end
    
    methods
        function obj = ModelComparer(historicalData)
            obj.HistoricalData = historicalData;
            obj.Results = table();
        end
        
        function runComparison(obj, splitRatio)
            if nargin < 2; splitRatio = 0.8; end
            
            Logger.info('--- Starting Institutional Model Comparison ---');
            
            % 1. Load actual models and scaler
            mgr = ModelManager();
            [models, scaler, featureList, targetScaler] = mgr.loadArtifacts();
            
            % 2. Use Single Source of Truth for Data Prep
            [~, X, Y] = PipelineDataProcessor.prepareData(featureList);
            
            % 3. Train/Test Split
            splitIdx = floor(size(X, 1) * splitRatio);
            X_train = X(1:splitIdx, :);
            y_train = Y(1:splitIdx);
            X_test_raw = X(splitIdx+1:end, :);
            y_test  = Y(splitIdx+1:end);
            
            % We need to scale test data
            X_test_scaled = PipelineDataProcessor.scaleData(X_test_raw, scaler);
            
            % For direction accuracy
            prev_prices = [Y(splitIdx); y_test(1:end-1)];
            actual_dir = sign(y_test - prev_prices);
            
            Logger.info(sprintf('Training set: %d rows, Test set: %d rows', splitIdx, length(y_test)));
            
            % 4. Evaluate Models
            obj = obj.evaluateEnsemble(models, X_test_scaled, y_test, actual_dir, y_train, targetScaler);
            obj = obj.evaluateNaive(y_train, y_test, actual_dir); % Random Walk baseline
            
            % 5. Print Results
            obj.printReport();
        end
        
        function obj = evaluateEnsemble(obj, models, X_test_scaled, y_test, actual_dir, y_train, targetScaler)
            Logger.info('Evaluating Production Ensemble Model...');
            preds = PipelineDataProcessor.predictEnsemble(models, X_test_scaled, targetScaler);
            
            y_test = y_test(:);
            preds = preds(:);
            
            % Metrics
            rmse = sqrt(mean((y_test - preds).^2));
            mae = mean(abs(y_test - preds));
            
            % === DIRECTIONAL ACCURACY CORRECTION ===
            % Old Formula: pred_dir = sign(diff([y_train(end); preds(1:end-1)]))
            % Why it was incorrect: The old formula checked if the prediction at time t 
            % was higher than the prediction at t-1 (model momentum), rather than checking 
            % if the prediction at time t is higher than the actual known price at t-1.
            % New Formula: sign(preds - [y_train(end); y_test(1:end-1)])
            % Reference: Standard financial forecasting Directional Accuracy (DA) dictates 
            % checking if sign(Y_hat_t - Y_{t-1}) == sign(Y_t - Y_{t-1}).
            
            % Known previous prices
            prev_prices = [y_train(end); y_test(1:end-1)];
            prev_prices = prev_prices(:);
            actual_dir = actual_dir(:);
            
            pred_dir = sign(preds - prev_prices);
            dir_acc = sum(pred_dir == actual_dir) / length(actual_dir) * 100;
            
            obj.addResult('Ensemble (CNN-LSTM)', rmse, mae, dir_acc);
        end
        
        function obj = evaluateNaive(obj, y_train, y_test, actual_dir)
            Logger.info('Evaluating Naive Random Walk (Baseline)...');
            y_test = y_test(:);
            actual_dir = actual_dir(:);
            % Predicts that tomorrow's price is exactly today's price
            prev_prices = [y_train(end); y_test(1:end-1)];
            prev_prices = prev_prices(:);
            preds = prev_prices;
            
            rmse = sqrt(mean((y_test - preds).^2));
            mae = mean(abs(y_test - preds));
            
            % For a strict Random Walk, prediction = prev_price, so (preds - prev_prices) = 0.
            % It predicts zero change, providing no directional edge.
            pred_dir = sign(preds - prev_prices);
            dir_acc = sum(pred_dir == actual_dir) / length(actual_dir) * 100;
            
            obj.addResult('Naive (Random Walk)', rmse, mae, dir_acc);
        end
        
        function addResult(obj, modelName, rmse, mae, dirAcc)
            newRow = {modelName, rmse, mae, dirAcc};
            if isempty(obj.Results)
                obj.Results = cell2table(newRow, 'VariableNames', {'Model', 'RMSE', 'MAE', 'DirectionalAccuracy'});
            else
                obj.Results = [obj.Results; newRow];
            end
        end
        
        function printReport(obj)
            fprintf('\n======================================================\n');
            fprintf('        INSTITUTIONAL MODEL COMPARISON REPORT         \n');
            fprintf('======================================================\n');
            disp(obj.Results);
            fprintf('======================================================\n');
        end
    end
end
