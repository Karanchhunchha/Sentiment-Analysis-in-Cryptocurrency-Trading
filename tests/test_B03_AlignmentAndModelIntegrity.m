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
            % Use a genuinely tiny dataset (5 obs) — far too few for ARIMA(1,1,1)
            yTiny = (1:5)';
            xTiny = (1:5)';
            arimaSpec = arima(1,1,1);
            
            % Must fail explicitly — 5 observations cannot estimate 4+ parameters
            try
                estimate(arimaSpec, yTiny, 'X', xTiny, 'Display', 'off');
                testCase.verifyFail('ARIMAX estimation should have thrown an error on insufficient data');
            catch ME
                % Verify the error is data-related, not an unrelated crash
                msgLower = lower(ME.message);
                testCase.verifyTrue( ...
                    contains(msgLower, 'observation') ...
                    || contains(msgLower, 'degrees of freedom') ...
                    || contains(msgLower, 'data') ...
                    || contains(msgLower, 'insufficient') ...
                    || contains(msgLower, 'presample'), ...
                    sprintf('Error should be data-related. Got: %s', ME.message));
            end
        end
        
        function testTruthfulMetadata(testCase)
            % Test I: Verify model_info.json contains truthful, internally consistent metadata
            infoPath = fullfile(pwd, 'models', 'model_info.json');
            testCase.verifyTrue(exist(infoPath, 'file') == 2, 'model_info.json must exist');
            
            fid = fopen(infoPath, 'r');
            raw = fread(fid, '*char')';
            fclose(fid);
            info = jsondecode(raw);
            
            % model_type must exist and be either 'ARIMA' or 'ARIMAX'
            testCase.verifyTrue(isfield(info, 'model_type'), 'Metadata must have model_type field');
            testCase.verifyTrue(ismember(info.model_type, {'ARIMA', 'ARIMAX'}), ...
                'model_type must be "ARIMA" or "ARIMAX"');
            
            % arima_model_type must exist and be a non-empty string
            testCase.verifyTrue(isfield(info, 'arima_model_type'), 'Metadata must have arima_model_type field');
            testCase.verifyTrue(~isempty(info.arima_model_type), 'arima_model_type must not be empty');
            
            % fallback_reason must exist
            testCase.verifyTrue(isfield(info, 'fallback_reason'), 'Metadata must have fallback_reason field');
            
            % Internal consistency: model_type and arima_model_type must agree
            if strcmp(info.model_type, 'ARIMAX')
                % ARIMAX succeeded: arima_model_type should start with ARIMAX
                testCase.verifyTrue(startsWith(info.arima_model_type, 'ARIMAX'), ...
                    'If model_type is ARIMAX, arima_model_type must start with ARIMAX');
                % fallback_reason should be empty when ARIMAX succeeded
                testCase.verifyTrue(isempty(info.fallback_reason), ...
                    'fallback_reason must be empty when ARIMAX succeeded');
            else
                % ARIMA fallback: arima_model_type should contain "Fallback"
                testCase.verifyTrue(contains(info.arima_model_type, 'Fallback'), ...
                    'arima_model_type must indicate ARIMA fallback');
                % fallback_reason must be non-empty to explain why ARIMAX failed
                testCase.verifyTrue(~isempty(info.fallback_reason), ...
                    'fallback_reason must not be empty when using ARIMA fallback');
            end
        end
        
        function testOneStepForecast(testCase)
            % Test J: Verify the saved model can produce a real, finite one-step forecast
            modelPath = fullfile(pwd, 'models', 'arima.mat');
            testCase.verifyTrue(exist(modelPath, 'file') == 2, 'arima.mat must exist');
            
            modelData = load(modelPath);
            mdl = modelData.arimaModel;
            testCase.verifyClass(mdl, 'arima', 'Loaded model must be arima class');
            
            % Load real price data as presample
            loader = PriceDataLoader('BTCUSDT', '1d');
            marketData = loader.loadHistoricalCSV('data/market/btc.csv');
            Y0 = marketData.Close(1:floor(0.8*height(marketData)));
            
            % Check if this is an ARIMAX model (has Beta coefficients)
            isArimax = ~isempty(mdl.Beta);
            
            % One-step forecast (ARIMAX requires XF for exogenous future values)
            if isArimax
                [yForecast, ~] = forecast(mdl, 1, 'Y0', Y0, 'XF', 0);
            else
                [yForecast, ~] = forecast(mdl, 1, 'Y0', Y0);
            end
            testCase.verifyTrue(isfinite(yForecast), 'One-step forecast must be finite');
            testCase.verifyTrue(yForecast > 0, 'BTC price forecast must be positive');
        end
        
        function testReproducibilityFromArtifact(testCase)
            % Test K: Verify saved artifact can be loaded and used consistently
            modelPath = fullfile(pwd, 'models', 'arima.mat');
            testCase.verifyTrue(exist(modelPath, 'file') == 2, 'arima.mat must exist');
            
            % Load twice and verify identical
            data1 = load(modelPath);
            data2 = load(modelPath);
            testCase.verifyTrue(isa(data1.arimaModel, 'arima'), 'Load 1: must be arima');
            testCase.verifyTrue(isa(data2.arimaModel, 'arima'), 'Load 2: must be arima');
            
            % Both should produce the same forecast from same presample
            Y0 = (1:200)';
            isArimax = ~isempty(data1.arimaModel.Beta);
            if isArimax
                XF = zeros(3, 1);  % neutral exogenous for 3 steps
                [f1, ~] = forecast(data1.arimaModel, 3, 'Y0', Y0, 'XF', XF);
                [f2, ~] = forecast(data2.arimaModel, 3, 'Y0', Y0, 'XF', XF);
            else
                [f1, ~] = forecast(data1.arimaModel, 3, 'Y0', Y0);
                [f2, ~] = forecast(data2.arimaModel, 3, 'Y0', Y0);
            end
            testCase.verifyEqual(f1, f2, 'AbsTol', 1e-10, 'Forecasts from same artifact must be identical');
        end
        
        function testRawDataChronologicalUnique(testCase)
            % Test L: Verify raw data files are sorted, unique, and chronological
            marketData = readtable(fullfile(pwd, 'data', 'market', 'btc.csv'));
            sentimentData = readtable(fullfile(pwd, 'data', 'sentiment', 'historical_daily_sentiment.csv'));
            
            marketDates = dateshift(datetime(marketData.Date), 'start', 'day');
            sentDates = dateshift(datetime(sentimentData.Date), 'start', 'day');
            
            % Market dates: sorted ascending
            testCase.verifyTrue(all(diff(marketDates) > 0), 'Market dates must be strictly ascending');
            % Market dates: unique
            testCase.verifyEqual(length(marketDates), length(unique(marketDates)), 'Market dates must be unique');
            
            % Sentiment dates: sorted ascending
            testCase.verifyTrue(all(diff(sentDates) > 0), 'Sentiment dates must be strictly ascending');
            % Sentiment dates: unique
            testCase.verifyEqual(length(sentDates), length(unique(sentDates)), 'Sentiment dates must be unique');
        end
    end
end
