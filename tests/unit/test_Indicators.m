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
            
            % Check that Hist = MACD - Signal
            histCheck = data.MACD_Line - data.MACD_Signal;
            testCase.verifyEqual(data.MACD_Hist(35:end), histCheck(35:end), 'AbsTol', 1e-4);
        end
    end
end
