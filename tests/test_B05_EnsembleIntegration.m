classdef test_B05_EnsembleIntegration < matlab.unittest.TestCase
    methods (Test)
        function testEnsembleWeightsActuallyUsed(testCase)
            % Change to project root to load models correctly
            oldPwd = pwd;
            cd('..');
            
            % Load artifacts
            mgr = ModelManager();
            [models, scaler, featureList, targetScaler] = mgr.loadArtifacts();
            
            % Mock weights to test if they affect output
            models.EnsembleWeights = [1.0, 0.0];
            [fullData, X, Y] = PipelineDataProcessor.prepareData(featureList);
            X_scaled = PipelineDataProcessor.scaleData(X, scaler);
            
            preds1 = PipelineDataProcessor.predictEnsemble(models, X_scaled, targetScaler);
            
            % Change weights
            models.EnsembleWeights = [0.0, 1.0];
            preds2 = PipelineDataProcessor.predictEnsemble(models, X_scaled, targetScaler);
            
            % Verify they are different
            testCase.verifyFalse(isequal(preds1, preds2), 'Predictions should differ with different weights');
            
            % Clean up
            cd(oldPwd);
        end
    end
end
