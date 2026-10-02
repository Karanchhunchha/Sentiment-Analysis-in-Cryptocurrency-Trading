classdef test_ReadinessSeparation < matlab.unittest.TestCase
    methods(Test)
        function testInfrastructureReadyVsModelQuality(testCase)
            report = VerificationReport('temp_reports');
            
            % Degraded model + Passing infrastructure
            report.setInfrastructureReady(true);
            report.setModelQualityGate('FAIL - REQUIRES_MODEL_IMPROVEMENT');
            
            testCase.verifyTrue(report.InfrastructureReady, 'Infrastructure should be PASS');
            testCase.verifyEqual(report.ModelQualityGate, 'FAIL - REQUIRES_MODEL_IMPROVEMENT', 'Model should be FAIL');
            % Infrastructure PASS ≠ ModelQuality PASS
            testCase.verifyNotEqual(report.InfrastructureReady, strcmp(report.ModelQualityGate, 'PASS'));
        end
        
        function testBenchmarkMetricsReporting(testCase)
            report = VerificationReport('temp_reports');
            report.addMetric('Benchmark', 'Ensemble_RMSE', 0.5, true);
            report.addMetric('Benchmark', 'Naive_Baseline_RMSE', 0.6, true);
            
            testCase.verifyTrue(report.Metrics.Benchmark.Ensemble_RMSE.Passed);
            testCase.verifyEqual(report.Metrics.Benchmark.Ensemble_RMSE.Value, 0.5);
        end
    end
end
