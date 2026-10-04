classdef test_B01_LookAheadBias < matlab.unittest.TestCase
    methods(Test)
        function testGoldenSMA(testCase) %#ok<MANU>
            Close = (1:60)';
            SMA_20 = movmean(Close, [19 0]);
            testCase.verifyEqual(SMA_20(51), 41.5, 'AbsTol', 1e-6, 'SMA_20(51) must equal trailing-window golden value 41.5');
        end
        function testFutureRowInvariance(testCase) %#ok<MANU>
            t = 50;
            dates = datetime(2026,1,1) + days(1:60)';
            df_base = table(dates, (1:60)', (1:60)'+1, (1:60)'-1, (1:60)', rand(60,1)*100, ...
                'VariableNames', {'Date', 'Open', 'High', 'Low', 'Close', 'Volume'});
            df_t = df_base(1:t, :);
            feat_t = FeatureEngineer.runAll(df_t);
            df_t2 = df_base;
            feat_t2 = FeatureEngineer.runAll(df_t2);
            vars = feat_t.Properties.VariableNames;
            for i = 1:length(vars)
                v = vars{i};
                if isnumeric(feat_t.(v))
                    d = max(abs(feat_t.(v) - feat_t2.(v)(1:t)));
                    testCase.verifyTrue(d <= 1e-10, sprintf('Feature %s changed based on future data (diff=%g)', v, d));
                end
            end
        end
    end
end
function runB01Tests()
    import matlab.unittest.TestSuite; import matlab.unittest.TestRunner;
    suite = TestSuite.fromClass(?test_B01_LookAheadBias); runner = TestRunner.withTextOutput(); runner.run(suite);
end
