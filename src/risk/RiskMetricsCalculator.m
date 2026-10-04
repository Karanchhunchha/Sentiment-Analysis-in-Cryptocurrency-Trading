classdef RiskMetricsCalculator
    methods(Static)
        function results = calculateAll(equityCurve)
            results = struct();
            if numel(equityCurve) <= 1
                results.SharpeRatio = 0;
                results.SortinoRatio = 0;
                results.VaR_95 = 0;
                results.CVaR_95 = 0;
                results.MaxDrawdown = 0;
                return;
            end
            
            eqDiff = diff(equityCurve);
            eqLag  = equityCurve(1:end-1);
            
            % Standardized returns calculation
            validMask = (eqLag > 0);
            returns = zeros(size(eqDiff));
            returns(validMask) = eqDiff(validMask) ./ eqLag(validMask);
            
            % Sharpe/Sortino (365 annualization constant implementation)
            annualFactor = sqrt(365);
            dailyRf = 0.02 / 365;
            excess = returns - dailyRf;
            
            results.SharpeRatio = 0;
            if std(excess) > 0
                results.SharpeRatio = annualFactor * mean(excess) / std(excess);
            end
            
            results.SortinoRatio = 0;
            downside = returns(returns < dailyRf);
            if numel(downside) > 0 && std(downside) > 0
                results.SortinoRatio = annualFactor * mean(excess) / std(downside);
            end
            
            % Empirical VaR/CVaR (95% confidence)
            sortedReturns = sort(returns);
            idx95 = max(1, floor(0.05 * length(sortedReturns)));
            
            results.VaR_95 = -sortedReturns(idx95);
            results.CVaR_95 = -mean(sortedReturns(1:idx95));
            
            % Max Drawdown
            peaks = cummax(equityCurve);
            drawdowns = (peaks - equityCurve) ./ max(peaks, 1);
            results.MaxDrawdown = max(drawdowns) * 100;
        end
    end
end
