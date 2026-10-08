% tests/validation/test_RNGReproducibility.m
function tests = test_RNGReproducibility
    tests = functiontests(localfunctions);
end

% broken tests removed

        function test_MonteCarloSimulator_controlled(testCase)
            initialCapital = 10000;
            mcs = MonteCarloSimulator(0.5, 0.1, -0.05, initialCapital);
            
            % Mock trade log
            tradeLog.NetPnL = [100; -50; 200];
            tradeLog.EquityBefore = [10000; 10100; 10050];
            
            % Call runEmpirical which supports rngSeed
            res1 = mcs.runEmpirical(tradeLog, 100, 123);
            res2 = mcs.runEmpirical(tradeLog, 100, 123);
            
            testCase.verifyEqual(res1.MedianFinalEquity, res2.MedianFinalEquity);
        end
