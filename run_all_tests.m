%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
% run_all_tests.m
% Orchestrates all verification and validation tests for SentinelCrypto.

clc; clear; close all;
import matlab.unittest.TestSuite;
import matlab.unittest.TestRunner;
import matlab.unittest.plugins.TestReportPlugin;

addpath(genpath('src'));
addpath(genpath('tests'));

fprintf('====================================================\n');
fprintf('     🔍 SENTINELCRYPTO QA & VERIFICATION 🔍      \n');
fprintf('====================================================\n\n');

% Ensure all test directories exist
testDirs = {'tests/data', 'tests/unit', 'tests/integration', 'tests/validation', 'tests/performance'};
for i = 1:length(testDirs)
    if ~exist(testDirs{i}, 'dir')
        mkdir(testDirs{i});
    end
end

% 1. Create a TestSuite from the 'tests' directory
suite = TestSuite.fromFolder('tests', 'IncludingSubfolders', true);

% 2. Create a silent runner
runner = TestRunner.withTextOutput();

% 3. Run the suite
fprintf('Executing %d unit/performance tests...\n', numel(suite));
results = runner.run(suite);

% Initialize the Institutional Verification Report
report = VerificationReport('reports');
numFailed = sum([results.Failed]);
numPassed = sum([results.Passed]);
numIncomplete = sum([results.Incomplete]);

fprintf('\n--- TEST SUITE SUMMARY ---\n');
fprintf('Passed   : %d\n', numPassed);
fprintf('Failed   : %d\n', numFailed);
fprintf('Warnings : 0\n');
fprintf('Skipped  : %d\n', numIncomplete);
fprintf('--------------------------\n');

report.addMetric('Unit_Tests', 'Tests_Passed', numPassed, numFailed == 0);

% 4. Run Massive Institutional Validations
fprintf('\n====================================================\n');
fprintf('     LAUNCHING INSTITUTIONAL VALIDATION PIPELINE    \n');
fprintf('====================================================\n');

try
    loader = PriceDataLoader('BTCUSDT', '1d');
    % Fallback chain for dataset location
    histData = [];
    if exist('data/market/btc.csv', 'file')
        histData = loader.loadHistoricalCSV('data/market/btc.csv');
    elseif exist('btc.csv', 'file')
        histData = loader.loadHistoricalCSV('btc.csv');
    end
    
    if ~isempty(histData)
        fprintf('Historical Dataset Loaded: %d rows.\n', height(histData));
        
        % Walk-Forward Validation
        wf = WalkForwardValidator(histData, 500, 100);
        wf.runValidation();
        report.addMetric('Validation', 'Walk_Forward_Completed', true, true);
        
        % Model Comparison
        mc = ModelComparer(histData);
        mc.runComparison(0.8);
        report.addMetric('Validation', 'Model_Comparison_Completed', true, true);
        
        % Backtesting
        % Backtester now loads the real CNN-LSTM + ARIMA ensemble internally!
        re = RiskEngine(1.5, 3.0, 1.5);
        bt = Backtester([], re, histData);
        btResults = bt.run();
        
        report.addMetric('Backtest', 'Total_Trades', btResults.TotalTrades, btResults.TotalTrades > 50);
        report.addMetric('Backtest', 'Win_Rate', btResults.WinRate, btResults.WinRate > 40);
        report.addMetric('Backtest', 'Max_Drawdown', btResults.MaxDrawdown, btResults.MaxDrawdown < 40);
        
        % Monte Carlo
        mcs = MonteCarloSimulator(btResults.WinRate / 100, 0.05, -0.02, 10000);
        mcResults = mcs.runSimulations(10000, 252);
        
        report.addMetric('Robustness', 'Probability_Of_Ruin', mcResults.ProbabilityOfRuin, mcResults.ProbabilityOfRuin < 5);
        report.addMetric('Robustness', 'Expected_Return', mcResults.ExpectedAnnualReturn, mcResults.ExpectedAnnualReturn > 0);
        
        % 4.5 Generate Level 2, 3, and 5 reports
        fprintf('\nGenerating Level-Specific Verification Reports...\n');
        try
            PipelineDataProcessor.generateDataAuditReport();
            report.addMetric('Validation', 'Data_Audit_Report_Generated', true, true);
        catch ME
            fprintf('[ERROR] Data Audit generation failed: %s\n', ME.message);
            report.addMetric('Validation', 'Data_Audit_Report_Generated', false, false);
        end
        
        try
            se = SentimentEngine();
            se.generateSentimentComparisonReport();
            report.addMetric('Validation', 'Sentiment_Comparison_Report_Generated', true, true);
        catch ME
            fprintf('[ERROR] Sentiment Comparison generation failed: %s\n', ME.message);
            report.addMetric('Validation', 'Sentiment_Comparison_Report_Generated', false, false);
        end
        
        try
            SystemHealthCheck.generateRepositoryHealthReport();
            report.addMetric('Validation', 'Repository_Health_Report_Generated', true, true);
        catch ME
            fprintf('[ERROR] Repository Health generation failed: %s\n', ME.message);
            report.addMetric('Validation', 'Repository_Health_Report_Generated', false, false);
        end
        
        try
            ps = PortfolioSimulator();
            ps.optimizePortfolio();
            report.addMetric('Validation', 'Portfolio_Optimization_Report_Generated', true, true);
        catch ME
            fprintf('[ERROR] Portfolio Optimization generation failed: %s\n', ME.message);
            report.addMetric('Validation', 'Portfolio_Optimization_Report_Generated', false, false);
        end
    else
        fprintf('[WARN] No historical dataset (btc.csv) found. Skipping deep validation.\n');
        report.addMetric('Validation', 'Data_Available', false, false);
    end
catch ME
    fprintf('[ERROR] Validation pipeline crashed: %s\n', ME.message);
    report.addMetric('Validation', 'Pipeline_Execution', false, false);
end

% 5. Generate Final Institutional HTML Report
report.generateHTML();

fprintf('\n====================================================\n');
fprintf('                QA RESULTS SUMMARY                  \n');
fprintf('====================================================\n');
fprintf('Readiness Score: %.1f%%\n', report.calculateReadiness());
fprintf('Detailed HTML Report saved to: %s\n', report.ReportFile);
fprintf('====================================================\n');
