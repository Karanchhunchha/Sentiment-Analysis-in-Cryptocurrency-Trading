function test_PortfolioOptimization()
    % Setup
    ps = PortfolioSimulator(10000);
    
    % Test deterministic output
    [w1, sharpe1, ~] = ps.optimizePortfolio();
    [w2, sharpe2, ~] = ps.optimizePortfolio();
    
    assert(norm(w1 - w2) < 1e-3, 'Portfolio weights should be close');
    assert(abs(sharpe1 - sharpe2) < 1e-3, 'Sharpe ratio should be close');
    assert(abs(sum(w1) - 1) < 1e-6, 'Weights should sum to 1.');
    assert(all(w1 >= -1e-6), 'Weights should be positive (or close to 0).');
    
    fprintf('test_PortfolioOptimization passed successfully!\n');
end
