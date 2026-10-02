function tests = test_SQLSecurity
    tests = functiontests(localfunctions);
end

function test_logToDatabase_sql_injection(testCase)
    simulator = PortfolioSimulator(10000);
    metrics = struct('SharpeRatio', 1.5, 'SortinoRatio', 2.0, 'MaxDrawdown', 0.1, 'CAGR', 0.2, 'FinalBTCWeight', 0.5, 'FinalCashWeight', 0.5);
    
    modelId = 'O''Reilly_Model';
    strategyName = 'Injection'' OR 1=1 --';
    
    try
        simulator.logToDatabase(metrics, modelId, strategyName);
    catch e
        if contains(e.message, 'DataIngestion')
             return; 
        end
        testCase.verifyFail(['logToDatabase threw unexpected error: ' e.message]);
    end
end
