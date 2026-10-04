classdef test_B04_LiveInferenceIntegration < matlab.unittest.TestCase
    % B4: live pipeline integration.
    %
    % Verifies that run_pipeline.m resolves the feature ordering from trained
    % model metadata (ModelManager.loadArtifacts) and forwards it into the
    % B5 five-argument predictEnsemble interface, and that the resulting live
    % inference path produces a finite raw-price prediction using the real
    % production artifacts.

    properties
        InitialDir
        RunPipelineFile
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            [folder, ~, ~] = fileparts(mfilename('fullpath'));
            testCase.InitialDir = pwd;
            cd(fullfile(folder, '..'));
            testCase.RunPipelineFile = fullfile(pwd, 'run_pipeline.m');
        end
    end

    methods (TestClassTeardown)
        function teardownOnce(testCase)
            cd(testCase.InitialDir);
        end
    end

    methods (Test)
        function processLiveTickSource(testCase)
            src = fileread(testCase.RunPipelineFile);
            startIdx = strfind(src, 'function processLiveTick(');
            testCase.verifyEqual(numel(startIdx), 1, ...
                'run_pipeline.m must define processLiveTick exactly once.');
            body = src(startIdx:end);

            sigEnd = strfind(body, newline);
            sig = body(1:sigEnd(1));
            testCase.verifyTrue(contains(sig, 'featureList'), ...
                'processLiveTick must receive featureList as a parameter; the live callback cannot see script-scope variables.');
        end

        function callbackForwardsFeatureList(testCase)
            src = fileread(testCase.RunPipelineFile);
            cbIdx = strfind(src, 'liveUpdateCallback = @(newCandle, fullData)');
            testCase.verifyEqual(numel(cbIdx), 1, ...
                'run_pipeline.m must build the live callback exactly once.');

            lineEnd = strfind(src(cbIdx(1):end), newline);
            cbLine = src(cbIdx(1):cbIdx(1)+lineEnd(1)-1);
            testCase.verifyTrue(contains(cbLine, 'processLiveTick(newCandle, fullData'), ...
                'The live callback must invoke processLiveTick.');
            testCase.verifyTrue(contains(cbLine, 'featureList'), ...
                'The live callback must forward the loaded featureList into processLiveTick.');
        end

        function featureListResolvedOnceFromMetadata(testCase)
            % featureListLive must be derived from the loaded metadata and then
            % reused for both the feature window and the predictEnsemble call, so
            % a single ordering governs both.
            src = fileread(testCase.RunPipelineFile);
            startIdx = strfind(src, 'function processLiveTick(');
            body = src(startIdx:end);

            testCase.verifyTrue(contains(body, 'featureListLive = featureList;'), ...
                'featureListLive must be sourced from the modelManager featureList.');
            testCase.verifyEqual(count(body, 'featureListLive = {'), 1, ...
                'featureListLive may have at most one fallback default ordering.');

            testCase.verifyTrue(contains(body, ...
                'featDataRaw = table2array(fullData_features(end-seqLen+1:end, featureListLive));'), ...
                'The feature window must be built with featureListLive.');
            testCase.verifyTrue(contains(body, ...
                'models, featScaled, targetScaler, scaler, featureListLive);'), ...
                'predictEnsemble must receive featureListLive.');
        end

        function usesFiveArgumentEnsembleInterface(testCase)
            src = fileread(testCase.RunPipelineFile);
            startIdx = strfind(src, 'function processLiveTick(');
            body = src(startIdx:end);

            testCase.verifyTrue(contains(body, ...
                'PipelineDataProcessor.predictEnsemble( ...'), ...
                'Live inference must go through PipelineDataProcessor.predictEnsemble.');
            testCase.verifyEqual(count(body, 'predictEnsemble('), 1, ...
                'There must be exactly one predictEnsemble call site in the live path.');
        end

        function noLegacyInferencePathsRemain(testCase)
            % Guards against reintroducing the B4 regressions: standalone LSTM
            % inference, three-way EnsembleWeights indexing, or an ARIMAX->CNN
            % fallback that would silently corrupt the ensemble blend.
            src = fileread(testCase.RunPipelineFile);
            startIdx = strfind(src, 'function processLiveTick(');
            body = src(startIdx:end);

            testCase.verifyFalse(contains(body, 'models.LSTM'), ...
                'Live inference must not call the standalone LSTM model.');
            testCase.verifyFalse(contains(body, 'EnsembleWeights(2)') || ...
                contains(body, 'EnsembleWeights(3)'), ...
                'Live inference must not index a three-way EnsembleWeights vector.');
            testCase.verifyFalse(contains(body, 'arimaPred = cnnPred'), ...
                'Live inference must not fall back to CNN output when ARIMAX is unavailable.');
            testCase.verifyFalse(contains(body, 'ensemblePred = NaN;'), ...
                'Live inference must not mask a failure as NaN.');

            testCase.verifyTrue(contains(body, 'rethrow(ME);'), ...
                'Inference failures must be rethrown rather than converted to a silent WAIT.');
        end

        function livePredictionReducedToScalar(testCase)
            % predictEnsemble returns a NaN-padded column. The live path must
            % reduce it to the scalar used by the signal, forecast, and risk
            % logic, and must fail loudly if nothing finite was produced.
            src = fileread(testCase.RunPipelineFile);
            startIdx = strfind(src, 'function processLiveTick(');
            body = src(startIdx:end);

            testCase.verifyTrue(contains(body, ...
                'ensemblePred = ensemblePredRaw(find(isfinite(ensemblePredRaw), 1, ''last''));'), ...
                'Live inference must select the last finite prediction from the padded column.');
            testCase.verifyTrue(contains(body, "if isempty(ensemblePred)"), ...
                'Live inference must reject a window with no finite prediction.');
            testCase.verifyTrue(contains(body, 'run_pipeline:NoValidPrediction'), ...
                'A fully invalid window must raise an explicit error, not a silent WAIT.');
        end

        function liveInferenceProducesFiniteRawPrice(testCase)
            % Reproduces the live inference path exactly: load the production
            % artifacts through ModelManager (the same source run_pipeline.m
            % uses), take the trailing 30-row window, scale it, and call the
            % five-argument interface.
            mgr = ModelManager();
            [models, scaler, featureList, targetScaler] = mgr.loadArtifacts();

            testCase.verifyNotEmpty(featureList, ...
                'ModelManager must return the trained feature ordering.');
            testCase.verifyTrue(ischar(featureList) || isstring(featureList) || iscell(featureList), ...
                'featureList must be a textual ordering.');

            [fullData, ~, ~] = PipelineDataProcessor.prepareData(featureList);

            seqLen = 30;
            testCase.verifyGreaterThanOrEqual(height(fullData), seqLen, ...
                'Live inference requires at least 30 historical rows.');

            window = fullData(end-seqLen+1:end, featureList);
            featDataRaw = table2array(window);
            testCase.verifyEqual(size(featDataRaw, 1), seqLen, ...
                'The live feature window must contain exactly 30 rows.');
            testCase.verifyEqual(size(featDataRaw, 2), numel(featureList), ...
                'The live feature window width must match the metadata feature count.');

            featScaled = PipelineDataProcessor.scaleData(featDataRaw, scaler);
            testCase.verifyTrue(all(isfinite(featScaled), 'all'), ...
                'Scaled live features must be finite.');

            preds = PipelineDataProcessor.predictEnsemble( ...
                models, featScaled, targetScaler, scaler, featureList);

            % predictEnsemble emits one output per input row, NaN-padded for
            % rows without a full sequence, so the live prediction is the last
            % finite entry.
            testCase.verifyEqual(size(preds, 1), seqLen, ...
                'predictEnsemble must return one output per input row.');
            testCase.verifyEqual(sum(isfinite(preds)), 1, ...
                'A single 30-row live window must yield exactly one finite prediction.');

            pred = preds(find(isfinite(preds), 1, 'last'));
            testCase.verifyTrue(isfinite(pred), 'The live prediction must be finite.');
            testCase.verifyGreaterThan(pred, 0, 'The live prediction must be a positive price.');
        end

        function liveWindowOrderingMatchesScalerWidth(testCase)
            % The ordering used to build the live window must agree with the
            % trained scaler width, otherwise scaleData silently mis-scales.
            mgr = ModelManager();
            [~, scaler, featureList] = mgr.loadArtifacts();

            testCase.verifyEqual(numel(featureList), numel(scaler.Min), ...
                'featureList length must match scaler.Min width.');
            testCase.verifyEqual(numel(featureList), numel(scaler.Max), ...
                'featureList length must match scaler.Max width.');
        end
    end
end