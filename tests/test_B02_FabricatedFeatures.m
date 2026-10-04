classdef test_B02_FabricatedFeatures < matlab.unittest.TestCase
    % test_B02_FabricatedFeatures Verifies that fabricated features (rand/randn/Close*0.99)
    % are removed from FeatureFusionEngine and replaced with mathematically correct
    % and deterministic RSI and EMA implementations.
    
    properties
        Engine
        History
    end
    
    methods(TestMethodSetup)
        function createEngine(testCase)
            testCase.Engine = FeatureFusionEngine();
            
            % Create 100 periods of synthetic data
            rng(42);
            dates = (datetime('today')-days(99):datetime('today'))';
            % Generate a random walk for prices
            closePrices = 100 + cumsum(randn(100, 1));
            volume = rand(100, 1) * 1000;
            testCase.History = table(dates, closePrices, volume, ...
                'VariableNames', {'Date', 'Close', 'Volume'});
        end
    end
    
    methods(Test)
        
        function testADeterminism(testCase)
            % Identical historical input produces identical RSI/EMA features
            rng('shuffle');
            [fusedData1, ~] = testCase.Engine.initializeHistorical(testCase.History);
            
            rng('shuffle');
            testCase.Engine = FeatureFusionEngine();
            [fusedData2, ~] = testCase.Engine.initializeHistorical(testCase.History);
            
            testCase.verifyEqual(fusedData1.RSI, fusedData2.RSI, 'RSI should be deterministic.');
            testCase.verifyEqual(fusedData1.EMA_20, fusedData2.EMA_20, 'EMA should be deterministic.');
        end
        
        function testBRSICorrectness(testCase)
            % Compare against an independently calculated expected RSI on a known sequence
            [fusedData, ~] = testCase.Engine.initializeHistorical(testCase.History);
            
            % Independent calculation of Wilder's RSI (14 period) - pre-allocated vectors
            closeP = testCase.History.Close;
            n = length(closeP);
            period = 14;
            diffs = [0; diff(closeP)];
            gains = max(0, diffs);
            losses = max(0, -diffs);
            
            avgGain = zeros(n, 1);
            avgLoss = zeros(n, 1);
            
            if n > period
                avgGain(period+1) = mean(gains(2:period+1));
                avgLoss(period+1) = mean(losses(2:period+1));
                
                for i = period+2:n
                    avgGain(i) = (avgGain(i-1)*(period-1) + gains(i))/period;
                    avgLoss(i) = (avgLoss(i-1)*(period-1) + losses(i))/period;
                end
            end
            
            rs = avgGain(end) / max(avgLoss(end), 1e-8);
            expectedRSI = 100 - (100 / (1 + rs));
            
            testCase.verifyEqual(fusedData.RSI(end), expectedRSI, 'AbsTol', 1e-6, 'RSI correctness failed.');
        end
        
        function testCEMACorrectness(testCase)
            % Compare against an independently calculated expected EMA
            [fusedData, ~] = testCase.Engine.initializeHistorical(testCase.History);
            
            closeP = testCase.History.Close;
            alpha = 2 / (20 + 1);
            ema = zeros(length(closeP), 1);
            ema(1) = closeP(1);
            for i = 2:length(closeP)
                ema(i) = (closeP(i) * alpha) + (ema(i-1) * (1 - alpha));
            end
            
            testCase.verifyEqual(fusedData.EMA_20, ema, 'AbsTol', 1e-6, 'EMA correctness failed.');
        end
        
        function testDIncrementalEquivalence(testCase)
            % initializeHistorical(history), followed by updateIncremental(new row),
            % must produce the same feature values as calculating the equivalent complete historical series.
            
            histPart = testCase.History(1:end-1, :);
            newRow = testCase.History(end, :);
            
            testCase.Engine.initializeHistorical(histPart);
            incResult = testCase.Engine.updateIncremental(newRow);
            
            % Now compute historically on the full set
            engine2 = FeatureFusionEngine();
            [fullData, ~] = engine2.initializeHistorical(testCase.History);
            
            testCase.verifyEqual(incResult.RSI, fullData.RSI(end), 'AbsTol', 1e-6, 'Incremental RSI mismatch.');
            testCase.verifyEqual(incResult.EMA_20, fullData.EMA_20(end), 'AbsTol', 1e-6, 'Incremental EMA mismatch.');
        end
        
        function testENoFutureDataDependence(testCase)
            % Changing a future price must not alter features already produced.
            [fusedOriginal, ~] = testCase.Engine.initializeHistorical(testCase.History);
            
            alteredHistory = testCase.History;
            alteredHistory.Close(end) = alteredHistory.Close(end) + 100;
            
            engine2 = FeatureFusionEngine();
            [fusedAltered, ~] = engine2.initializeHistorical(alteredHistory);
            
            % All features prior to the final row must remain identical
            testCase.verifyEqual(fusedAltered.RSI(1:end-1), fusedOriginal.RSI(1:end-1), 'Future data leak detected in RSI.');
            testCase.verifyEqual(fusedAltered.EMA_20(1:end-1), fusedOriginal.EMA_20(1:end-1), 'Future data leak detected in EMA.');
        end
        
        function testFRepeatedUpdates(testCase)
            % Repeated identical input/state transitions behave deterministically.
            testCase.Engine.initializeHistorical(testCase.History);
            
            newRow = table(datetime('today')+days(1), 150, 1000, 'VariableNames', {'Date', 'Close', 'Volume'});
            
            rng('shuffle');
            inc1 = testCase.Engine.updateIncremental(newRow);
            
            % Reinitialize to the same state
            testCase.Engine.initializeHistorical(testCase.History);
            rng('shuffle');
            inc2 = testCase.Engine.updateIncremental(newRow);
            
            testCase.verifyEqual(inc1.RSI, inc2.RSI, 'Repeated incremental RSI should be deterministic.');
            testCase.verifyEqual(inc1.EMA_20, inc2.EMA_20, 'Repeated incremental EMA should be deterministic.');
        end
        
        function testGLatency(testCase)
            % Measure latency of updateIncremental
            testCase.Engine.initializeHistorical(testCase.History);
            newRow = table(datetime('today')+days(1), 150, 1000, 'VariableNames', {'Date', 'Close', 'Volume'});
            
            % Warmup
            for i = 1:10
                testCase.Engine.updateIncremental(newRow);
            end
            
            % Measure
            numUpdates = 1000;
            tic;
            for i = 1:numUpdates
                testCase.Engine.updateIncremental(newRow);
            end
            elapsed = toc;
            avgLatencyMs = (elapsed / numUpdates) * 1000;
            
            fprintf('Average updateIncremental Latency: %.3f ms\n', avgLatencyMs);
            testCase.verifyLessThan(avgLatencyMs, 50, 'Latency exceeded 50ms requirement.');
        end
    end
end
