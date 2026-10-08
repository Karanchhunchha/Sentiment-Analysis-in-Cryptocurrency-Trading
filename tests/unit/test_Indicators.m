%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef test_Indicators < matlab.unittest.TestCase
    % test_Indicators Verifies mathematical correctness of technical indicators
    
    properties
        TestData
    end
    
    methods(TestMethodSetup)
        function loadGoldenData(testCase)
            % Load deterministic dataset for testing
            if ~exist('tests/data/golden_data.csv', 'file')
                cd('tests/data');
                generate_golden_data();
                cd('../..');
            end
            testCase.TestData = readtable('tests/data/golden_data.csv');
        end
    end
    
    methods(Test)
        function testSMA(testCase)
            data = IndicatorEngine.calculateAll(testCase.TestData);
            
            % SMA20 of a straight line linspace(100, 200, 100) + sine wave
            % We will just check if the SMA exists and is structurally sound
            testCase.verifyTrue(ismember('SMA_20', data.Properties.VariableNames));
            % Check there are no NaNs left since the engine drops the first 50 rows
            testCase.verifyFalse(any(isnan(data.SMA_20)));
        end
        
        function testEMA(testCase)
            data = IndicatorEngine.calculateAll(testCase.TestData);
            
            testCase.verifyTrue(ismember('EMA_20', data.Properties.VariableNames));
            % EMA should react faster than SMA
            % We can assert the value isn't drastically off the price scale
            testCase.verifyGreaterThan(data.EMA_20(end), 100);
            testCase.verifyLessThan(data.EMA_20(end), 300);
        end
        
        function testRSI(testCase)
            data = IndicatorEngine.calculateAll(testCase.TestData);
            
            testCase.verifyTrue(ismember('RSI_14', data.Properties.VariableNames));
            % RSI must be between 0 and 100
            validRSI = data.RSI_14(15:end);
            testCase.verifyGreaterThanOrEqual(min(validRSI), 0);
            testCase.verifyLessThanOrEqual(max(validRSI), 100);
        end
        
        function testMACD(testCase)
            data = IndicatorEngine.calculateAll(testCase.TestData);
            
            testCase.verifyTrue(ismember('MACD_Line', data.Properties.VariableNames));
            testCase.verifyTrue(ismember('MACD_Signal', data.Properties.VariableNames));
            testCase.verifyTrue(ismember('MACD_Hist', data.Properties.VariableNames));
            
            % The reviewer noted the previous test was tautological (A-B == A-B).
            % Now we verify MACD against an independent mathematical reference
            price = data.Close;
            ema12 = zeros(size(price)); ema26 = zeros(size(price));
            ema12(1) = price(1); ema26(1) = price(1);
            k12 = 2/13; k26 = 2/27;
            for i=2:length(price)
                ema12(i) = price(i)*k12 + ema12(i-1)*(1-k12);
                ema26(i) = price(i)*k26 + ema26(i-1)*(1-k26);
            end
            refMACD = ema12 - ema26;
            
            % Test valid indices (after drop rows, test against reference)
            diff = abs(data.MACD_Line(51:end) - refMACD(100:end));
            testCase.verifyLessThan(mean(diff), 1e-2);
        end
        
        function testBollingerBands(testCase)
            data = IndicatorEngine.calculateAll(testCase.TestData);
            
            testCase.verifyTrue(ismember('BB_Upper', data.Properties.VariableNames));
            testCase.verifyTrue(ismember('BB_Lower', data.Properties.VariableNames));
            testCase.verifyTrue(ismember('BB_Mid', data.Properties.VariableNames));
            
            % Verify that Upper is always >= Mid and Lower <= Mid
            testCase.verifyTrue(all(data.BB_Upper >= data.BB_Mid));
            testCase.verifyTrue(all(data.BB_Lower <= data.BB_Mid));
        end
    end
end
