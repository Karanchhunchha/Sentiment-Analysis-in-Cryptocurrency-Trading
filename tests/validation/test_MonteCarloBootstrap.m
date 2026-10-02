function test_MonteCarloBootstrap()
    % Setup
    initialCapital = 10000;
    mc = MonteCarloSimulator(0.5, 0.05, -0.04, initialCapital);
    
    % Test empty handling
    success = false;
    try
        mc.runEmpirical(struct(), 100);
    catch
        success = true;
    end
    assert(success, 'Should have failed on empty input');
    
    % Test reproducibility
    tradeLog.NetPnL = [100; -50; 200; -100];
    tradeLog.EquityBefore = [10000; 10100; 10050; 10250];
    
    res1 = mc.runEmpirical(tradeLog, 100, 123);
    res2 = mc.runEmpirical(tradeLog, 100, 123);
    assert(isequal(res1, res2), 'Results should be reproducible');
    
    % Test logic with actual NetPnL
    % With fixed seed 123, results should be consistent
    assert(res1.MedianFinalEquity > initialCapital, 'Median result should be above initial');
    
    fprintf('test_MonteCarloBootstrap passed successfully!\n');
end
