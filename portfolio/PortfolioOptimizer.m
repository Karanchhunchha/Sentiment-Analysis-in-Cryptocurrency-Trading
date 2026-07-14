% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto

classdef PortfolioOptimizer < handle
    % PORTFOLIOOPTIMIZER Pure MATLAB implementation of Markowitz Mean-Variance
    % Allocates between BTC and Cash (2-asset portfolio) using closed-form
    % matrix algebra, strictly avoiding the Financial Toolbox.
    
    properties
        RiskTolerance = 2.0; % Gamma parameter: higher means lower risk tolerance
        RiskFreeRate = 0.0;  % Assuming 0% return on uninvested cash for crypto
    end
    
    methods
        function obj = PortfolioOptimizer(riskTolerance)
            if nargin > 0
                obj.RiskTolerance = riskTolerance;
            end
        end
        
        function weights = optimize(obj, expectedReturnBTC, volatilityBTC)
            % Calculates the optimal weight [w_btc, w_cash]
            % Uses the analytical solution for a risk-free asset + one risky asset:
            % w_risky = (mu_risky - r_f) / (gamma * sigma_risky^2)
            
            % Prevent division by zero if volatility is artificially 0
            if volatilityBTC < 1e-6
                volatilityBTC = 1e-6;
            end
            
            % 1. Calculate unconstrained optimal weight for BTC
            w_btc_unconstrained = (expectedReturnBTC - obj.RiskFreeRate) / (obj.RiskTolerance * (volatilityBTC^2));
            
            % 2. Apply Long-Only Constraint (0 <= w <= 1)
            % This prevents short-selling (w < 0) and leverage (w > 1)
            w_btc = max(0, min(1, w_btc_unconstrained));
            
            % 3. Calculate Cash weight (the remainder)
            w_cash = 1 - w_btc;
            
            % Return as a 2x1 vector: [Weight_BTC; Weight_Cash]
            weights = [w_btc; w_cash];
        end
        
        function weights = optimizeCovariance(obj, expectedReturns, covMatrix)
            % Generic N-asset closed form solution (Lagrange multiplier)
            % Provided for completeness, though 2-asset analytical is used.
            % w = inv(Sigma) * 1 / (1' * inv(Sigma) * 1) (Minimum Variance)
            
            % Add small ridge to diagonal to ensure invertibility
            covMatrix = covMatrix + eye(size(covMatrix)) * 1e-8;
            
            invCov = inv(covMatrix);
            onesVec = ones(size(expectedReturns, 1), 1);
            
            % Tangency portfolio (assuming r_f = 0)
            w_unconstrained = (invCov * expectedReturns) / (onesVec' * invCov * expectedReturns);
            
            % Simple heuristic projection to enforce long-only sum-to-1
            w_long = max(0, w_unconstrained);
            if sum(w_long) == 0
                weights = onesVec / length(onesVec); % Equal weight fallback
            else
                weights = w_long / sum(w_long);
            end
        end
    end
end
