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
    
    assert(res1.MedianFinalEquity > initialCapital, 'Median result should be above initial');

    tbl = table(tradeLog.NetPnL, tradeLog.EquityBefore, 'VariableNames', {'NetPnL','EquityBefore'});
    rt = mc.runEmpirical(tbl, 100, 123);
    assert(isequal(rt.MedianFinalEquity, res1.MedianFinalEquity), 'Struct and table TradeLog must give same result');

    tradeLog2.NetPnL = [500; 400; 300; 200];
    tradeLog2.EquityBefore = [10000; 10500; 11000; 11500];
    res3 = mc.runEmpirical(tradeLog2, 100, 123);
    assert(res3.MedianFinalEquity ~= res1.MedianFinalEquity, 'Bootstrap must depend on input trade returns');

    fprintf('test_MonteCarloBootstrap passed successfully!\n');
end
