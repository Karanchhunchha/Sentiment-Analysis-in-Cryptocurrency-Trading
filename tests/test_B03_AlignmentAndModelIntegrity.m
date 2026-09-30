classdef test_B03_AlignmentAndModelIntegrity < matlab.unittest.TestCase
    
    properties
        TestData
        TestSentiment
        Processor
    end
    
    methods (TestClassSetup)
        function setupOnce(testCase)
            % Ensure we are in the root directory for relative paths
            [folder, ~, ~] = fileparts(mfilename('fullpath'));
            cd(fullfile(folder, '..'));
        end
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            % Use small mock dataset for testing time alignment without loading large files
            dates = datetime(2023,1,1:10)';
            closeP = (100:10:190)';
            testCase.TestData = table(dates, closeP, ...
                'VariableNames', {'Date', 'Close'});
            
            % Sentiment with a gap on Jan 4 and Jan 8
            sentDates = dates([1, 2, 3, 5, 6, 7, 9, 10]);
            sentVals = (1:8)';
            testCase.TestSentiment = table(sentDates, sentVals, ...
                'VariableNames', {'Date', 'Daily_Sentiment'});
        end
    end
    
    methods (Test)
        function testModelArtifactIntegrity(testCase)
            % Test A: Verify persisted ARIMA artifact is genuine
            % Note: Pipeline should be run before this test to generate model
            try
                modelData = load(fullfile(pwd, 'models', 'arima.mat'));
                testCase.verifyTrue(isfield(modelData, 'arimaModel'), 'arima.mat should contain arimaModel');
                
                modelObj = modelData.arimaModel;
                testCase.verifyNotEqual(class(modelObj), 'struct', 'ARIMA model should not be a struct (stub)');
                testCase.verifyClass(modelObj, 'arima', 'Artifact should be genuine ARIMA object');
                
                % The model should be estimated, not just specified
                testCase.verifyNotEmpty(modelObj.Variance, 'Model variance should be estimated');
            catch ME
                testCase.verifyFail(['Failed to load or verify model artifact: ', ME.message]);
            end
        end
        
        function testTimeGridCorrectness(testCase)
            % Test B & C: Verify expected daily timestamps and ordering
            % Write mock data to files just for the pipeline test
            writetable(testCase.TestData, 'test_mock_market.csv');
            writetable(testCase.TestSentiment, 'test_mock_sentiment.csv');
            
            % Override loaders temporarily (or just test the logic directly)
            marketData = testCase.TestData;
            sentimentData = testCase.TestSentiment;
            
            marketData.Date = dateshift(datetime(marketData.Date), 'start', 'day');
            sentimentData.Date = dateshift(datetime(sentimentData.Date), 'start', 'day');
            marketTT = table2timetable(marketData, 'RowTimes', 'Date');
            sentimentTT = table2timetable(sentimentData, 'RowTimes', 'Date');
            fullDataTT = synchronize(marketTT, sentimentTT, 'daily', 'previous');
            
            % Verify grid
            dt = diff(fullDataTT.Date);
            testCase.verifyEqual(unique(dt), hours(24), 'Time grid must be strictly continuous daily (24 hours)');
            
            % Verify forward fill (previous)
            % Jan 4 is missing in sentiment, should be filled with Jan 3 value (3)
            idxJan4 = find(fullDataTT.Date == datetime(2023, 1, 4));
            testCase.verifyEqual(fullDataTT.Daily_Sentiment(idxJan4), 3, 'Missing data should be forward-filled');
            
            delete('test_mock_market.csv');
            delete('test_mock_sentiment.csv');
        end
        
        function testTargetAlignment(testCase)
            % Test E: Verify target t corresponds to future observation
            [fullData, ~, ~] = PipelineDataProcessor.prepareData();
            
            % Check first row
            targetT1 = fullData.Target(1);
            closeT2 = fullData.Close(2);
            testCase.verifyEqual(targetT1, closeT2, 'Target at t should be Close at t+1');
        end
        
        function testNoFutureDataLeakage(testCase)
            % Test D: Changing future observations must not alter historical features/targets
            [fullData1, ~, ~] = PipelineDataProcessor.prepareData();
            
            % Read original data and corrupt the last row
            loader = PriceDataLoader('BTCUSDT', '1d');
            marketData = loader.loadHistoricalCSV('data/market/btc.csv');
            marketData.Close(end) = 999999;
            writetable(marketData, 'test_corrupt_market.csv');
            
            % Manually run preparation on corrupted data
            sentimentData = readtable('data/sentiment/historical_daily_sentiment.csv');
            marketData.Date = dateshift(datetime(marketData.Date), 'start', 'day');
            sentimentData.Date = dateshift(datetime(sentimentData.Date), 'start', 'day');
            marketTT = table2timetable(marketData, 'RowTimes', 'Date');
            sentimentTT = table2timetable(sentimentData, 'RowTimes', 'Date');
            fullDataTT = synchronize(marketTT, sentimentTT, 'daily', 'previous');
            fullData2 = timetable2table(fullDataTT);
            fullData2.Properties.VariableNames{1} = 'Date';
            fullData2 = rmmissing(fullData2, 'DataVariables', 'Close');
            if any(ismissing(fullData2.Daily_Sentiment)), fullData2.Daily_Sentiment(ismissing(fullData2.Daily_Sentiment)) = 0; end
            if any(ismissing(fullData2.Tweet_Volume)), fullData2.Tweet_Volume(ismissing(fullData2.Tweet_Volume)) = 0; end
            fullData2 = IndicatorEngine.calculateAll(fullData2);
            fullData2.Target = [fullData2.Close(2:end); NaN];
            fullData2(end, :) = [];
            
            % Compare everything EXCEPT the last row (which changed due to target shift and its own value)
            nCompare = height(fullData1) - 2;
            testCase.verifyEqual(fullData1.SMA_20(1:nCompare), fullData2.SMA_20(1:nCompare), 'Historical SMA should not change');
            testCase.verifyEqual(fullData1.Target(1:nCompare), fullData2.Target(1:nCompare), 'Historical Target should not change');
            
            delete('test_corrupt_market.csv');
        end
        
        function testChronologicalSplit(testCase)
            % Test F: Verify train/test boundaries do not overlap
            [fullData, X, Y] = PipelineDataProcessor.prepareData();
            splitIdx = floor(0.8 * size(X, 1));
            
            trainDates = fullData.Date(1:splitIdx);
            testDates = fullData.Date(splitIdx+1:end);
            
            testCase.verifyTrue(max(trainDates) < min(testDates), 'Train dates must strictly precede test dates');
        end
        
        function testInsufficientDataBehavior(testCase)
            % Test H: Verify insufficient data produces an explicit failure
            yAll = (1:184)';
            xAll = (1:184)';
            arimaSpec = arima(1,1,1);
            
            % Should fail explicitly for ARIMAX since we need more observations for the X regressor
            try
                estimate(arimaSpec, yAll, 'X', xAll, 'Display', 'off');
                testCase.verifyFail('ARIMAX estimation should have thrown an error on insufficient data');
            catch ME
                testCase.verifyTrue(contains(lower(ME.message), 'observations') || contains(lower(ME.message), 'degrees of freedom') || contains(lower(ME.message), 'data'), 'Should throw data size error');
            end
        end
    end
end
