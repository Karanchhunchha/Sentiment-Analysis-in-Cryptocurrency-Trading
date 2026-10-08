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
            % SMA20 golden reference: Close = (1:60)', SMA20(51) MUST equal 41.5.
            data = testCase.TestData(1:60, :);
            data.Close = (1:60)';
            out = IndicatorEngine.calculateAll(data);
            
            testCase.verifyTrue(ismember('SMA_20', out.Properties.VariableNames));
            % Note: IndicatorEngine drops first 50 rows.
            % So row 51 in original data becomes row 1 in output data.
            testCase.verifyEqual(out.SMA_20(1), 41.5, 'AbsTol', 1e-4);
        end
        
        function testFutureRowInvariance(testCase)
            % Changing future observations must not change earlier indicator outputs
            data1 = testCase.TestData(1:100, :);
            data2 = testCase.TestData(1:100, :);
            data2.Close(90:100) = 99999; % Alter future rows
            
            out1 = IndicatorEngine.calculateAll(data1);
            out2 = IndicatorEngine.calculateAll(data2);
            
            % Compare output for row 80 (which is index 30 after 50 warm-up dropped)
            testCase.verifyEqual(out1.SMA_20(30), out2.SMA_20(30));
            testCase.verifyEqual(out1.RSI_14(30), out2.RSI_14(30));
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
            price = testCase.TestData.Close;
            ema12 = zeros(size(price)); ema26 = zeros(size(price));
            ema12(1) = price(1); ema26(1) = price(1);
            k12 = 2/13; k26 = 2/27;
            for i=2:length(price)
                ema12(i) = price(i)*k12 + ema12(i-1)*(1-k12);
                ema26(i) = price(i)*k26 + ema26(i-1)*(1-k26);
            end
            refMACD = ema12 - ema26;
            
            % Test valid indices (after drop rows, test against reference)
            diff = abs(data.MACD_Line - refMACD(51:end));
            testCase.verifyLessThan(mean(diff), 1e-2);
        end
        
        function testBollingerBands(testCase)
            data = IndicatorEngine.calculateAll(testCase.TestData);
            
            testCase.verifyTrue(ismember('BB_Upper', data.Properties.VariableNames));
            testCase.verifyTrue(ismember('BB_Lower', data.Properties.VariableNames));
            
            % Verify that Upper is always >= Mid and Lower <= Mid (Mid is SMA_20)
            testCase.verifyTrue(all(data.BB_Upper >= data.SMA_20));
            testCase.verifyTrue(all(data.BB_Lower <= data.SMA_20));
        end
    end
end
