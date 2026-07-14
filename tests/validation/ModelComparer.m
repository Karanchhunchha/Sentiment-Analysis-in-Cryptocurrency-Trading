classdef ModelComparer < handle
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
            actual_dir = sign(diff([Y(splitIdx); y_test(1:end-1)]));
            
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
            
            % Metrics
            rmse = sqrt(mean((y_test - preds).^2));
            mae = mean(abs(y_test - preds));
            pred_dir = sign(diff([y_train(end); preds(1:end-1)]));
            dir_acc = sum(pred_dir == actual_dir) / length(actual_dir) * 100;
            
            obj.addResult('Ensemble (CNN-LSTM)', rmse, mae, dir_acc);
        end
        
        function obj = evaluateNaive(obj, y_train, y_test, actual_dir)
            Logger.info('Evaluating Naive Random Walk (Baseline)...');
            % Predicts that tomorrow's price is exactly today's price
            preds = [y_train(end); y_test(1:end-1)];
            
            rmse = sqrt(mean((y_test - preds).^2));
            mae = mean(abs(y_test - preds));
            pred_dir = sign(diff([y_train(end); preds(1:end-1)]));
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
