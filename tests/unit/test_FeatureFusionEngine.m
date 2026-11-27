classdef test_FeatureFusionEngine < matlab.unittest.TestCase
    % test_FeatureFusionEngine Verifies state tracking and incremental
    % updates inside the FeatureFusionEngine to ensure zero data leakage and
    % fast execution.
    
    properties
        Engine
        SyntheticData
    end
    
    methods(TestMethodSetup)
        function createEngine(testCase)
            testCase.Engine = FeatureFusionEngine();
            % Create synthetic historical data
            dates = (datetime('today')-days(100):datetime('today'))';
            closePrices = linspace(100, 200, 101)';
            testCase.SyntheticData = table(dates, closePrices, closePrices.*0+10, 'VariableNames', {'Date', 'Close', 'Volume'});
        end
    end
    
    methods(Test)
        function testInitialization(testCase)
            [~, currentState] = testCase.Engine.initializeHistorical(testCase.SyntheticData);
            
            % Assert state is populated
            testCase.verifyFalse(isempty(testCase.Engine.LastClose));
            testCase.verifyFalse(isempty(testCase.Engine.LastEMA));
            
            % Assert LastClose matches the last row
            testCase.verifyEqual(testCase.Engine.LastClose, 200);
            
            % Assert currentState contains required columns
            testCase.verifyTrue(ismember('EMA_20', currentState.Properties.VariableNames));
        end
        
        function testIncrementalUpdate(testCase)
            testCase.Engine.initializeHistorical(testCase.SyntheticData);
            
            % Create a live tick
            newCandle = table(datetime('now'), 205, 50, 'VariableNames', {'Date', 'Close', 'Volume'});
            
            lastEMA = testCase.Engine.LastEMA;
            
            tic;
            liveVector = testCase.Engine.updateIncremental(newCandle);
            execTime = toc;
            
            % The engine should execute in less than 50ms (0.05 seconds)
            testCase.verifyLessThan(execTime, 0.05, 'Incremental update exceeded 50ms latency target.');
            
            % Verify math for EMA update
            alpha = 2 / (20 + 1);
            expectedEMA = (205 * alpha) + (lastEMA * (1 - alpha));
            
            testCase.verifyEqual(liveVector.EMA_20(1), expectedEMA, 'AbsTol', 1e-4);
            testCase.verifyEqual(testCase.Engine.LastClose, 205);
        end
        
        function testEmptyInitializationFallback(testCase)
            % Test what happens if updateIncremental is called before initialization
            emptyEngine = FeatureFusionEngine();
            newCandle = table(datetime('now'), 50000, 100, 'VariableNames', {'Date', 'Close', 'Volume'});
            
            liveVector = emptyEngine.updateIncremental(newCandle);
            
            % The EMA should default to current price if it was empty
            testCase.verifyEqual(liveVector.EMA_20(1), 50000);
            testCase.verifyEqual(emptyEngine.LastEMA, 50000);
        end
        
        function testDeterministicReplay(testCase)
            % Determinism: replaying the identical input sequence through two
            % fresh engines (initializeHistorical + updateIncremental) must
            % produce bit-identical RSI/EMA outputs. Guards against hidden
            % randomness (rand/randn) creeping back into the fused features.
            ticks = [202; 198; 205; 210; 207; 215; 220; 218];
            
            fusedRuns = cell(1, 2);
            rsiRuns = zeros(numel(ticks), 2);
            emaRuns = zeros(numel(ticks), 2);
            for run = 1:2
                engine = FeatureFusionEngine();
                [fusedData, ~] = engine.initializeHistorical(testCase.SyntheticData);
                fusedRuns{run} = fusedData;
                for k = 1:numel(ticks)
                    candle = table(datetime('now'), ticks(k), 100, ...
                        'VariableNames', {'Date', 'Close', 'Volume'});
                    liveVector = engine.updateIncremental(candle);
                    rsiRuns(k, run) = liveVector.RSI(1);
                    emaRuns(k, run) = liveVector.EMA_20(1);
                end
            end
            
            % Batch initialization must be exactly reproducible
            testCase.verifyTrue(isequal(fusedRuns{1}.RSI, fusedRuns{2}.RSI), ...
                'initializeHistorical RSI must be identical across replays.');
            testCase.verifyTrue(isequal(fusedRuns{1}.EMA_20, fusedRuns{2}.EMA_20), ...
                'initializeHistorical EMA_20 must be identical across replays.');
            
            % Incremental updates must be exactly reproducible
            testCase.verifyTrue(isequal(rsiRuns(:, 1), rsiRuns(:, 2)), ...
                'updateIncremental RSI must be identical across replays.');
            testCase.verifyTrue(isequal(emaRuns(:, 1), emaRuns(:, 2)), ...
                'updateIncremental EMA_20 must be identical across replays.');
        end
    end
end
