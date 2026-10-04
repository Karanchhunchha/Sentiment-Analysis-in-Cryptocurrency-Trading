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
            
            raw = char(fileread('src/risk/RiskMetricsCalculator.m'));
            testCase.verifyTrue(contains(raw, 'sqrt(365)'), 'RiskMetricsCalculator must use 365-day annualization');
            testCase.verifyFalse(contains(raw, 'sqrt(252)'), 'RiskMetricsCalculator must not use 252-day annualization');
            rawPS = char(fileread('src/strategy/PortfolioSimulator.m'));
            testCase.verifyTrue(contains(rawPS, 'N = 365'), 'PortfolioSimulator must use 365');
            testCase.verifyFalse(contains(rawPS, '* 252'), 'PortfolioSimulator.optimizePortfolio must not use 252');

            ret = diff(equityCurve)./equityCurve(1:end-1);
            expectedSharpe = sqrt(365) * mean(ret - 0.02/365) / std(ret - 0.02/365);
            testCase.verifyEqual(results.SharpeRatio, expectedSharpe, 'AbsTol', 1e-9, 'Sharpe must match 365-annualized equity returns');

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
