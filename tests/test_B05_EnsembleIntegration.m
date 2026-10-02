classdef test_B05_EnsembleIntegration < matlab.unittest.TestCase
    properties
        InitialDir
        PipelineFile
        ModelComparerFile
    end
    
    methods (TestClassSetup)
        function setupOnce(testCase)
            % Anchor the working directory at the project root so relative
            % data/model paths resolve regardless of the launch directory.
            testCase.InitialDir = pwd;
            [folder, ~, ~] = fileparts(mfilename('fullpath'));
            root = fullfile(folder, '..');
            cd(root);
            testCase.PipelineFile = fullfile(root, 'src', 'data', 'PipelineDataProcessor.m');
            testCase.ModelComparerFile = fullfile(folder, 'validation', 'ModelComparer.m');
        end
    end
    
    methods (TestClassTeardown)
        function teardownOnce(testCase)
            cd(testCase.InitialDir);
        end
    end
    
    methods
        function assertErrorIdSuffix(testCase, fn, suffix)
            % MATLAB rewrites the leading component of an error identifier for
            % class methods, so match on the trailing component instead.
            didError = false;
            try
                fn();
            catch ME
                didError = true;
                testCase.verifyTrue(endsWith(ME.identifier, suffix), ...
                    sprintf('Expected an error identifier ending in "%s", got "%s".', suffix, ME.identifier));
            end
            testCase.verifyTrue(didError, ...
                sprintf('Expected an error ending in "%s", but none was raised.', suffix));
        end
    end
    
    methods (Test)
        function testWeightsActuallyChangeOutput(testCase)
            [models, scaler, featureList, targetScaler, X_scaled] = loadProductionContext();
            
            models.EnsembleWeights = [1.0, 0.0];
            preds1 = PipelineDataProcessor.predictEnsemble(models, X_scaled, targetScaler, scaler, featureList);
            
            models.EnsembleWeights = [0.0, 1.0];
            preds2 = PipelineDataProcessor.predictEnsemble(models, X_scaled, targetScaler, scaler, featureList);
            
            testCase.verifyFalse(isequal(preds1, preds2), ...
                'Predictions must differ when ensemble weights change from [1,0] to [0,1].');
            
            diff = preds1 - preds2;
            validDiff = diff(~isnan(diff));
            testCase.verifyTrue(any(validDiff ~= 0), ...
                'Predictions must change by a meaningful amount when weights change.');
        end
        
        function testEnsembleOutputFinite(testCase)
            [models, scaler, featureList, targetScaler, X_scaled] = loadProductionContext();
            models.EnsembleWeights = [0.6, 0.4];
            
            preds = PipelineDataProcessor.predictEnsemble(models, X_scaled, targetScaler, scaler, featureList);
            
            validPreds = preds(~isnan(preds));
            testCase.verifyTrue(all(isfinite(validPreds)), ...
                'All ensemble predictions must be finite.');
        end
        
        function testCNNAndARIMAXSameScale(testCase)
            [models, scaler, featureList, targetScaler, X_scaled] = loadProductionContext();
            models.EnsembleWeights = [1.0, 0.0];
            
            closeIdx = find(strcmp(featureList, 'Close'), 1);
            [X_seq, ~] = PipelineDataProcessor.formatForCNNLSTM(X_scaled);
            cnnPredsScaled = double(predict(models.CNN, X_seq));
            cnnPreds = PipelineDataProcessor.unscaleTarget(cnnPredsScaled, targetScaler);
            
            X_raw = X_scaled .* (scaler.Max - scaler.Min) + scaler.Min;
            sentimentIdx = find(strcmp(featureList, 'Daily_Sentiment'), 1);
            
            % Rolling 1-step ARIMAX forecast matching CNN-LSTM
            numSamples = length(cnnPreds);
            arimaPreds = zeros(numSamples, 1);
            for i = 1:numSamples
                y0Idx = max(min(size(X_scaled,1) - numSamples + i, size(X_raw,1)), 2);
                y0Raw = X_raw(y0Idx-1:y0Idx, closeIdx);
                xfVal = X_raw(min(y0Idx, size(X_raw,1)), sentimentIdx);
                arimaPreds(i) = forecast(models.ARIMA, 1, 'Y0', y0Raw, 'XF', xfVal);
            end
            arimaPreds = arimaPreds(:);
            
            testCase.verifyTrue(all(isfinite(cnnPreds)) && all(isfinite(arimaPreds)), ...
                'Both CNN and ARIMAX predictions must be finite.');
            
            % Scale invariant: both sub-models must produce raw-price magnitudes,
            % not [0,1] scaled values. Compare to the target scaler's range.
            testCase.verifyTrue(median(cnnPreds) > 100, ...
                'CNN predictions must be in raw price space, not scaled space.');
            testCase.verifyTrue(median(arimaPreds) > 100, ...
                'ARIMAX predictions must be in raw price space, not scaled space.');
            
            % Both sub-models must be within the same raw-price order of magnitude.
            % (They cannot be compared if one is ~1e0 scaled and the other ~1e5 raw.)
            ratio = median(arimaPreds) / median(cnnPreds);
            testCase.verifyTrue(ratio > 0.01 && ratio < 100, ...
                sprintf('CNN and ARIMAX outputs must be in the same raw scale, got ratio %.4f', ratio));
        end
        
        function testCorrectY0SentToARIMAX(testCase)
            [models, scaler, featureList, targetScaler, X_scaled] = loadProductionContext();
            [fullData, ~, ~] = PipelineDataProcessor.prepareData(featureList);
            models.EnsembleWeights = [0.0, 1.0];
            
            preds = PipelineDataProcessor.predictEnsemble(models, X_scaled, targetScaler, scaler, featureList);
            
            lastTwoCloseRaw = fullData.Close(end-1:end);
            
            % Y0 must be the raw Close in price space (~$60k), NOT a scaled
            % value (~0.1) and NOT an incorrect early row (~0.1).
            testCase.verifyTrue(lastTwoCloseRaw(1) > 1000, ...
                sprintf('Y0 must be raw Close (~60k), got %.4f', lastTwoCloseRaw(1)));
            testCase.verifyTrue(lastTwoCloseRaw(2) > 1000, ...
                sprintf('Y0 second element must be raw Close (~60k), got %.4f', lastTwoCloseRaw(2)));
            
            % The ARIMAX sub-model must be finite everywhere.
            validPreds = preds(~isnan(preds));
            testCase.verifyTrue(all(isfinite(validPreds)), ...
                'ARIMAX (weights [0,1]) predictions must be finite.');
            
            % In the recent regime where Y0 ~ $60k the ARIMAX forecast must be
            % in the same raw-price scale as the observed Close (positive and
            % within the target range), proving Y0 was raw and not scaled.
            recentPreds = validPreds(end-50:end);
            testCase.verifyTrue(all(recentPreds > 0), ...
                'Recent ARIMAX predictions (Y0 ~ $60k) must be positive raw prices.');
            testCase.verifyTrue(median(recentPreds) > 1000, ...
                sprintf('Recent ARIMAX predictions must be raw prices, got median %.2f', median(recentPreds)));
            testCase.verifyTrue(median(recentPreds) < 1e7, ...
                'Recent ARIMAX predictions must not diverge to absurd magnitudes.');
        end
        
        function testXFNonZeroSentimentSentToARIMAX(testCase)
            [models, scaler, featureList, targetScaler, X_scaled] = loadProductionContext();
            models.EnsembleWeights = [0.0, 1.0];
            
            preds = PipelineDataProcessor.predictEnsemble(models, X_scaled, targetScaler, scaler, featureList);
            
            sentimentIdx = find(strcmp(featureList, 'Daily_Sentiment'), 1);
            X_raw = X_scaled .* (scaler.Max - scaler.Min) + scaler.Min;
            lastSentiment = X_raw(end, sentimentIdx);
            
            testCase.verifyTrue(isfinite(lastSentiment) && lastSentiment ~= 0, ...
                'XF must be a non-zero, finite sentiment value.');
            
            validPreds = preds(~isnan(preds));
            testCase.verifyTrue(std(validPreds) > 1e3, ...
                'ARIMAX predictions must show variance (XF is non-trivial).');
        end
        
        function testEnsembleAlignedWithValidRows(testCase)
            [models, scaler, featureList, targetScaler, X_scaled] = loadProductionContext();
            models.EnsembleWeights = [0.6, 0.4];
            
            preds = PipelineDataProcessor.predictEnsemble(models, X_scaled, targetScaler, scaler, featureList);
            
            sequenceLength = 30;
            expectedNumValid = size(X_scaled, 1) - sequenceLength + 1;
            
            validPreds = preds(~isnan(preds));
            testCase.verifyEqual(length(validPreds), expectedNumValid, ...
                'Number of non-NaN predictions must equal the number of valid sequence rows.');
            
            lastValidIdx = find(isfinite(preds), 1, 'last');
            testCase.verifyEqual(lastValidIdx, length(preds), ...
                'The last prediction must occupy the final index.');
        end
        
        function testARIMAXStubIsRejectedNotSubstituted(testCase)
            % A stubbed (struct) ARIMAX model must raise an error. It must
            % never be silently replaced by CNN output, which would make the
            % ARIMAX ensemble weight a lie.
            [models, scaler, featureList, targetScaler, X_scaled] = loadProductionContext();
            
            models.ARIMA = struct('isStub', true);
            
            testCase.assertErrorIdSuffix(@() PipelineDataProcessor.predictEnsemble( ...
                models, X_scaled, targetScaler, scaler, featureList), ...
                'predictEnsemble:ARIMAMissing');
        end
        
        function testMissingARIMAXIsRejected(testCase)
            [models, scaler, featureList, targetScaler, X_scaled] = loadProductionContext();
            models = rmfield(models, 'ARIMA');
            
            testCase.assertErrorIdSuffix(@() PipelineDataProcessor.predictEnsemble( ...
                models, X_scaled, targetScaler, scaler, featureList), ...
                'predictEnsemble:ARIMAMissing');
        end
        
        function testForecastFailureSurfacesExplicitly(testCase)
            % A forecasting error inside the ARIMAX rolling loop must propagate
            % to the caller. It must never be caught and replaced by CNN output.
            [models, scaler, featureList, targetScaler, X_scaled] = loadProductionContext();
            
            models.ARIMA = 'not-a-model';
            
            didError = false;
            try
                PipelineDataProcessor.predictEnsemble(models, X_scaled, targetScaler, scaler, featureList);
            catch ME
                didError = true;
                testCase.verifyFalse(endsWith(ME.identifier, 'predictEnsemble:ARIMAMissing'), ...
                    'The raised error must originate from the forecast call, not from the stub guard.');
            end
            testCase.verifyTrue(didError, ...
                'predictEnsemble must propagate ARIMAX forecasting errors instead of falling back to CNN.');
        end
        
        function testMissingScalerIsRejected(testCase)
            [models, ~, featureList, targetScaler, X_scaled] = loadProductionContext();
            
            testCase.assertErrorIdSuffix(@() PipelineDataProcessor.predictEnsemble( ...
                models, X_scaled, targetScaler, [], featureList), ...
                'predictEnsemble:MissingScaler');
        end
        
        function testMissingFeatureListIsRejected(testCase)
            [models, scaler, ~, targetScaler, X_scaled] = loadProductionContext();
            
            testCase.assertErrorIdSuffix(@() PipelineDataProcessor.predictEnsemble( ...
                models, X_scaled, targetScaler, scaler, {}), ...
                'predictEnsemble:MissingFeatureList');
        end
        
        function testNoSilentFallbackInSource(testCase)
            % Static guard against reintroduction of the silent
            % `catch -> arimaPreds(i) = cnnPreds(i)` substitution.
            src = fileread(testCase.PipelineFile);
            
            startIdx = strfind(src, 'function preds = predictEnsemble');
            stopIdx = strfind(src, 'function generateDataAuditReport');
            testCase.verifyEqual(numel(startIdx), 1, 'predictEnsemble must be defined exactly once.');
            testCase.verifyEqual(numel(stopIdx), 1, 'Unable to bound the predictEnsemble method body.');
            
            body = src(startIdx:stopIdx-1);
            
            % Ignore comment lines so prose cannot trip the guard.
            lines = splitlines(string(body));
            lines = lines(~startsWith(strtrim(lines), "%"));
            code = strjoin(lines, newline);
            
            testCase.verifyFalse(contains(code, 'catch'), ...
                'predictEnsemble must not swallow ARIMAX forecasting errors.');
            testCase.verifyFalse(contains(code, 'arimaPreds = cnnPreds'), ...
                'ARIMAX output must never be silently substituted with CNN output.');
            testCase.verifyFalse(contains(code, 'arimaPreds(i) = cnnPreds(i)'), ...
                'Per-sample ARIMAX failures must never be silently replaced by CNN output.');
        end
        
        function testModelComparerThreadsScalerAndFeatureList(testCase)
            % evaluateEnsemble must accept scaler and featureList so that the
            % 5-argument predictEnsemble signature can be satisfied.
            mc = meta.class.fromName('ModelComparer');
            testCase.verifyNotEmpty(mc, 'ModelComparer class must be on the path.');
            
            names = {mc.MethodList.Name};
            idx = find(strcmp(names, 'evaluateEnsemble'), 1);
            testCase.verifyNotEmpty(idx, 'ModelComparer must define evaluateEnsemble.');
            
            numInputs = numel(mc.MethodList(idx).Signature(1).Inputs);
            testCase.verifyEqual(numInputs, 9, ...
                'evaluateEnsemble must take (obj, models, X_test_scaled, y_test, actual_dir, y_train, targetScaler, scaler, featureList).');
            
            src = fileread(testCase.ModelComparerFile);
            testCase.verifyTrue(contains(src, ...
                'function obj = evaluateEnsemble(obj, models, X_test_scaled, y_test, actual_dir, y_train, targetScaler, scaler, featureList)'), ...
                'evaluateEnsemble must declare scaler and featureList parameters.');
            testCase.verifyTrue(contains(src, ...
                'predictEnsemble(models, X_test_scaled, targetScaler, scaler, featureList)'), ...
                'ModelComparer must call predictEnsemble with the 5-argument signature.');
            testCase.verifyTrue(contains(src, ...
                'targetScaler, scaler, featureList);'), ...
                'runComparison must forward scaler and featureList into evaluateEnsemble.');
        end
    end
end

function [models, scaler, featureList, targetScaler, X_scaled] = loadProductionContext()
    mgr = ModelManager();
    [models, scaler, featureList, targetScaler] = mgr.loadArtifacts();
    [~, X, ~] = PipelineDataProcessor.prepareData(featureList);
    X_scaled = PipelineDataProcessor.scaleData(X, scaler);
end