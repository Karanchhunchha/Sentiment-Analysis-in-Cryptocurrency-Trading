classdef test_B07_WalkForward < matlab.unittest.TestCase

    properties
        RootDir
        WFFile
        PreparedData
        FoldRecords
        Metrics
        FoldCount
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            [folder, ~, ~] = fileparts(mfilename('fullpath')); %#ok<NASGU>
            testCase.RootDir = fullfile(folder, '..');
            cd(testCase.RootDir);
            testCase.WFFile = fullfile(testCase.RootDir, 'tests', 'validation', 'WalkForwardValidator.m');

            wf = WalkForwardValidator([], 500, 100);
            pd = wf.buildPreparedData();
            testCase.PreparedData = pd;
            testCase.FoldCount = numel(WalkForwardValidator.computeFoldBoundaries(size(pd.X, 1), 500, 100));

            wf2 = WalkForwardValidator([], 500, 100);
            wf2.PreparedData = pd;
            wf2.runValidation();
            testCase.FoldRecords = wf2.getFoldRecords();
            testCase.Metrics = wf2.getMetrics();
        end
    end

    methods (Test)

        function testFoldCountIs44AndWindowsCorrect(testCase)
            testCase.verifyEqual(testCase.FoldCount, 44);
            folds = WalkForwardValidator.computeFoldBoundaries(size(testCase.PreparedData.X, 1), 500, 100);
            testCase.verifyEqual(folds(1).TrainStart, 1);
            testCase.verifyEqual(folds(1).TrainEnd, 500);
            testCase.verifyEqual(folds(1).TestStart, 501);
            testCase.verifyEqual(folds(1).TestEnd, 600);
            testCase.verifyEqual(folds(2).TrainStart, 101);
            testCase.verifyEqual(folds(44).TrainEnd, 4800);
            testCase.verifyEqual(folds(44).TestEnd, 4900);
            for k = 1:numel(folds)
                testCase.verifyEqual(folds(k).TestEnd - folds(k).TestStart + 1, 100);
                testCase.verifyEqual(folds(k).TestStart, folds(k).TrainEnd + 1);
            end
        end

        function testPredictionCountEqualsStepSize(testCase)
            for k = 1:numel(testCase.FoldRecords)
                testCase.verifyEqual(testCase.FoldRecords(k).NumPredictions, 100);
                testCase.verifyEqual(testCase.FoldRecords(k).TestEnd - testCase.FoldRecords(k).TestStart + 1, 100);
            end
            testCase.verifyEqual(sum([testCase.FoldRecords.NumPredictions]), testCase.Metrics.NumPredictions);
            testCase.verifyEqual(testCase.Metrics.DAccScored, testCase.Metrics.NumPredictions);
        end

        function testNoTestRowEntersFoldTrainingData(testCase)
            for k = 1:numel(testCase.FoldRecords)
                r = testCase.FoldRecords(k);
                testCase.verifyTrue(r.TrainEnd < r.TestStart);
                testCase.verifyEqual(r.TrainTargetMaxRow, r.TrainEnd);
                testCase.verifyTrue(r.TrainSequenceMinRow >= r.TrainStart);
                testCase.verifyTrue(r.EvalTargetMinRow == r.TestStart);
                testCase.verifyTrue(r.EvalTargetMaxRow == r.TestEnd);
            end
        end

        function testFoldSpecificScalersAreIndependent(testCase)
            recs = testCase.FoldRecords;
            testCase.verifyGreaterThan(numel(recs), 2);
            s1 = recs(1).ScalerMin;
            s10 = recs(10).ScalerMin;
            s44 = recs(end).ScalerMin;
            testCase.verifyFalse(isequal(s1, s10));
            testCase.verifyFalse(isequal(s1, s44));
        end

        function testDirectionalAccuracyMatchesHandComputedKnownExample(testCase)
            prev = [100; 101; 102; 104; 103];
            preds = [101; 102.5; 101.5; 105; 102.5];
            actual = [102; 101; 103; 103.5; 104];
            [da, info] = WalkForwardValidator.computeDirectionalAccuracy(prev, preds, actual);
            % pred_dir: [sign(pred-prev)] = [1, 1, -1, 1, -1]
            % act_dir:  [sign(act -prev)] = [1, 0,  1,-1,  1]
            % hits:  r1 match, r2-5 miss = 1, scored=5 => DA=20%
            testCase.verifyEqual(info.Scored, 5);
            testCase.verifyEqual(info.Hits, 1);
            testCase.verifyEqual(da, 20, 'AbsTol', 1e-12);
        end

        function testFirstPredictionUsesYOfTrainEndAsPreviousPrice(testCase)
            recs = testCase.FoldRecords;
            for k = 1:numel(recs)
                testCase.verifyEqual(recs(k).PredictionFirstPrevPrice, testCase.PreparedData.Y(recs(k).TrainEnd));
                testCase.verifyEqual(recs(k).PrevPrices(1), testCase.PreparedData.Y(recs(k).TrainEnd));
                testCase.verifyEqual(recs(k).PredictionFirstActual, testCase.PreparedData.Y(recs(k).TestStart));
            end
            [dacc, ~] = WalkForwardValidator.computeDirectionalAccuracy( ...
                [recs(1).PrevPrices(1)], recs(1).Predictions(1:1), recs(1).Actuals(1:1));
            testCase.verifyTrue(isfinite(dacc));
        end

        function testZeroMovementHandlingDoesNotCreateFalseHits(testCase)
            prev = [100; 100; 100; 100];
            preds = [100; 100; 100; 100];
            actual = [101; 99; 100; 100];
            [da, info] = WalkForwardValidator.computeDirectionalAccuracy(prev, preds, actual);
            % pred_dir = [0,0,0,0]; act_dir=[+, -, 0, 0]
            % hits = 2 (rows 3,4), scored=4, flatPred=4, flatActual=2
            testCase.verifyEqual(info.FlatPredictions, 4);
            testCase.verifyEqual(info.FlatActuals, 2);
            testCase.verifyEqual(info.Hits, 2);
            testCase.verifyEqual(da, 50, 'AbsTol', 1e-12);
        end

        function testProductionModelArtifactsNotUsedAsFoldModels(testCase)
            testCase.verifyFalse(testCase.Metrics.ProductionArtifactsUsed);
            testCase.verifyTrue(testCase.Metrics.PerFoldRetraining);
            for k = 1:numel(testCase.FoldRecords)
                testCase.verifyFalse(testCase.FoldRecords(k).ProductionArtifactUsed);
                testCase.verifyTrue(strcmp(testCase.FoldRecords(k).ModelSource, 'retrained-inside-fold'));
            end
        end

        function testScalerWidthsMatchFeatureCount(testCase)
            nFeatures = size(testCase.PreparedData.X, 2);
            for k = 1:numel(testCase.FoldRecords)
                testCase.verifyEqual(numel(testCase.FoldRecords(k).ScalerMin), nFeatures);
                testCase.verifyEqual(numel(testCase.FoldRecords(k).ScalerMax), nFeatures);
            end
        end

        function testPerformedMultipleFoldsRetrainIndependently(testCase)
            recs = testCase.FoldRecords;
            % Fingerprints across folds must not be identical.
            fps = {recs.ModelFingerprint};
            testCase.verifyTrue(numel(unique(fps)) >= 10);
            % Train targets: every fold with TrainWindow=500 and SequenceLength=30
            % produces exactly 500-30+1 = 471 training sequences.
            testCase.verifyTrue(all([recs.NumTrainSequences] == 471));
            testCase.verifyEqual(testCase.Metrics.NumFolds, 44);
        end

        function testValidatorStaticMethodsExist(testCase)
            testCase.verifyTrue(isa(@() WalkForwardValidator.computeFoldBoundaries(1000, 500, 100), 'function_handle') || ...
                ~isempty(which('WalkForwardValidator')));
            testCase.verifyTrue(~isempty(which('WalkForwardValidator')));
            wf = WalkForwardValidator([], 500, 100);
            testCase.verifyTrue(isa(wf.computeFoldBoundaries(1000, 500, 100), 'struct'));
        end
    end
end
