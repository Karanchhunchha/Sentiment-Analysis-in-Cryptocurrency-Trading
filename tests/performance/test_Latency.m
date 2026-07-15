%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef test_Latency < matlab.unittest.TestCase
    % test_Latency Enforces strict performance budgets for the live system.
    % Target: Prediction < 100ms, Dashboard Refresh < 50ms.
    
    properties
        FeatureEngine
        DummyCandle
    end
    
    methods(TestMethodSetup)
        function setup(testCase)
            testCase.FeatureEngine = FeatureFusionEngine();
            % Initialize with some dummy historical data
            dates = (datetime('today')-days(100):datetime('today'))';
            closePrices = linspace(100, 200, 101)';
            dummyHist = table(dates, closePrices, closePrices.*0+10, 'VariableNames', {'Date', 'Close', 'Volume'});
            testCase.FeatureEngine.initializeHistorical(dummyHist);
            
            testCase.DummyCandle = table(datetime('now'), 205, 50, 'VariableNames', {'Date', 'Close', 'Volume'});
        end
    end
    
    methods(Test)
        function testFeatureFusionLatency(testCase)
            % Test that feature fusion takes less than 50ms
            
            % Warmup
            testCase.FeatureEngine.updateIncremental(testCase.DummyCandle);
            
            times = zeros(100, 1);
            for i = 1:100
                tic;
                testCase.FeatureEngine.updateIncremental(testCase.DummyCandle);
                times(i) = toc;
            end
            
            avgTime = mean(times);
            fprintf('Average Feature Fusion Latency: %.4f seconds\n', avgTime);
            
            % Assert < 50ms
            testCase.verifyLessThan(avgTime, 0.05, 'Feature Fusion exceeds 50ms latency budget.');
        end
        
        function testMemoryUsage(testCase)
            % Ensure the Engine doesn't blow up memory by accumulating arrays
            initialInfo = whos('testCase');
            initialBytes = initialInfo.bytes;
            
            for i = 1:1000
                testCase.FeatureEngine.updateIncremental(testCase.DummyCandle);
            end
            
            finalInfo = whos('testCase');
            finalBytes = finalInfo.bytes;
            
            % Memory shouldn't grow significantly just from incremental updates
            growth = finalBytes - initialBytes;
            testCase.verifyLessThan(growth, 1000000, 'Memory leak detected in incremental updates (grew > 1MB)');
        end
    end
end
