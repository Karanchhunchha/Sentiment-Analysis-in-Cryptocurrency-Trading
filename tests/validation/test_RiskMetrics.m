classdef test_RiskMetrics < matlab.unittest.TestCase
    methods(Test)
        function testRiskMetricsCalculation(testCase)
            % Ensure metrics match expectations: Sharpe, Sortino, Drawdown, VaR, CVaR
            equityCurve = [10000, 10100, 10050, 10200, 10150, 10300];
            results = RiskMetricsCalculator.calculateAll(equityCurve);
            
            testCase.verifyTrue(isfield(results, 'SharpeRatio'));
            testCase.verifyTrue(isfield(results, 'SortinoRatio'));
            testCase.verifyTrue(isfield(results, 'MaxDrawdown'));
            testCase.verifyTrue(isfield(results, 'VaR_95'));
            testCase.verifyTrue(isfield(results, 'CVaR_95'));
            
            % 365 Check (verifyAnnualization)
            % (Sharpe ratio depends on sqrt(365))
            % Basic verification: Sharpe > 0 for overall rising equity
            testCase.verifyGreaterThan(results.SharpeRatio, 0);
            testCase.verifyGreaterThan(results.MaxDrawdown, 0);
        end

        function testEdgeCases(testCase)
            % Flat equity
            resultsFlat = RiskMetricsCalculator.calculateAll([100, 100, 100]);
            testCase.verifyEqual(resultsFlat.SharpeRatio, 0);
            testCase.verifyEqual(resultsFlat.SortinoRatio, 0);
            
            % Insufficient observations
            resultsShort = RiskMetricsCalculator.calculateAll([100]);
            testCase.verifyEqual(resultsShort.SharpeRatio, 0);
        end
    end
end
