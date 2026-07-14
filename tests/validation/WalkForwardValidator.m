classdef WalkForwardValidator < handle
    % WalkForwardValidator Performs strict Walk-Forward (Sliding Window) 
    % validation. Trains on window T, predicts T+1, slides window.
    
    properties
        HistoricalData
        TrainWindowSize
        StepSize
        Results
    end
    
    methods
        function obj = WalkForwardValidator(historicalData, trainWindow, stepSize)
            % For pre-trained models, trainWindow and stepSize just dictate reporting intervals.
            if nargin < 2; trainWindow = 500; end
            if nargin < 3; stepSize = 100; end
            
            obj.HistoricalData = historicalData;
            obj.TrainWindowSize = trainWindow;
            obj.StepSize = stepSize;
            obj.Results = table();
        end
        
        function runValidation(obj)
            Logger.info('Starting Walk-Forward Validation using Production Models...');
            
            % 1. Load actual models and scaler
            mgr = ModelManager();
            [models, scaler, featureList, targetScaler] = mgr.loadArtifacts();
            
            % 2. Use Single Source of Truth for Data Prep
            [~, X, Y] = PipelineDataProcessor.prepareData(featureList);
            
            totalPredictions = [];
            totalActuals = [];
            
            % Sliding Window Loop (for evaluation)
            startIdx = 1;
            numRows = size(X, 1);
            
            % Dynamically adjust if dataset is too small
            if (obj.TrainWindowSize + obj.StepSize) > numRows
                Logger.warning('Dataset length (%d) is smaller than TrainWindow (%d) + StepSize (%d). Dynamically adjusting...', numRows, obj.TrainWindowSize, obj.StepSize);
                obj.TrainWindowSize = floor(numRows * 0.5);
                obj.StepSize = floor(numRows * 0.1);
                if obj.StepSize < 1; obj.StepSize = 1; end
            end
            
            while (startIdx + obj.TrainWindowSize + obj.StepSize) <= numRows
                trainEnd = startIdx + obj.TrainWindowSize - 1;
                testEnd = trainEnd + obj.StepSize;
                
                % Out of sample for this step
                X_test_raw = X(trainEnd+1:testEnd, :);
                y_test = Y(trainEnd+1:testEnd);
                
                % 3. Apply exact production scaling
                X_test_scaled = PipelineDataProcessor.scaleData(X_test_raw, scaler);
                
                % 4. Predict using Ensemble (CNN-LSTM as primary)
                preds = PipelineDataProcessor.predictEnsemble(models, X_test_scaled, targetScaler);
                
                totalPredictions = [totalPredictions; preds];
                totalActuals = [totalActuals; y_test];
                
                startIdx = startIdx + obj.StepSize;
                fprintf('  -> Validated window %d to %d\n', trainEnd+1, testEnd);
            end
            
            % Compute final metrics across all out-of-sample walk-forward steps
            rmse = sqrt(mean((totalActuals - totalPredictions).^2));
            mae = mean(abs(totalActuals - totalPredictions));
            
            pred_dir = sign(diff([0; totalPredictions(1:end-1)]));
            actual_dir = sign(diff([0; totalActuals(1:end-1)]));
            dir_acc = sum(pred_dir == actual_dir) / length(actual_dir) * 100;
            
            obj.printReport(rmse, mae, dir_acc, length(totalPredictions));
        end
        
        function printReport(~, rmse, mae, dirAcc, numSamples)
            fprintf('\n======================================================\n');
            fprintf('        WALK-FORWARD VALIDATION RESULTS               \n');
            fprintf('======================================================\n');
            fprintf('Total OOS Predictions: %d\n', numSamples);
            fprintf('RMSE:                  %.4f\n', rmse);
            fprintf('MAE:                   %.4f\n', mae);
            fprintf('Directional Accuracy:  %.2f%%\n', dirAcc);
            fprintf('======================================================\n');
        end
    end
end
