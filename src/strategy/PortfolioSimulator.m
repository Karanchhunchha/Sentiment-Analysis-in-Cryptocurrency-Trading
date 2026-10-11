classdef PortfolioSimulator
    % PortfolioSimulator Backtests strategy and computes risk metrics
    
    properties
        InitialCapital = 10000;
        TransactionFee = 0.001; % 0.1% Binance tier
        SlippageRate = 0.0005;  % 0.05% slippage rate
        AnnualizationFactor = 365; % Default daily; adjusted for 15m (365*24*4 = 35040)
    end
    
    methods
        function obj = PortfolioSimulator(initialCapital, annualizationFactor, slippageRate)
            if nargin > 0 && ~isempty(initialCapital)
                obj.InitialCapital = initialCapital;
            end
            if nargin > 1 && ~isempty(annualizationFactor)
                obj.AnnualizationFactor = annualizationFactor;
            end
            if nargin > 2 && ~isempty(slippageRate)
                obj.SlippageRate = slippageRate;
            end
        end
        
        function metrics = runSimulation(obj, priceData, predictions, modelId, strategyName, timestamps)
            % Compute equity curve based on predictions with explicit timestamp and length validation.
            cleanPreds = predictions(:);
            cleanPrices = priceData(:);
            
            if length(cleanPreds) ~= length(cleanPrices)
                error('PortfolioSimulator:LengthMismatch', ...
                    'PortfolioSimulator: length of predictions (%d) does not match priceData (%d). Silent truncation forbidden.', ...
                    length(cleanPreds), length(cleanPrices));
            end
            
            if nargin >= 6 && ~isempty(timestamps)
                cleanTimes = timestamps(:);
                if length(cleanTimes) ~= length(cleanPrices)
                    error('PortfolioSimulator:TimestampMismatch', ...
                        'PortfolioSimulator: length of timestamps (%d) does not match priceData (%d).', ...
                        length(cleanTimes), length(cleanPrices));
                end
            end
            
            signals = zeros(size(cleanPreds));
            for i = 2:length(cleanPreds)
                if isnan(cleanPreds(i)) || isnan(cleanPrices(i))
                    signals(i) = 0;
                else
                    if cleanPreds(i) > cleanPrices(i)
                        signals(i) = 1;
                    elseif cleanPreds(i) < cleanPrices(i)
                        signals(i) = -1;
                    else
                        signals(i) = 0;
                    end
                end
            end
            signals(1) = 0;
            
            returns = diff(cleanPrices) ./ cleanPrices(1:end-1);
            returns = [0; returns];
            
            equity = zeros(length(returns), 1);
            equity(1) = obj.InitialCapital;
            
            strategyReturns = zeros(length(returns), 1);
            position = 0; 
            
            for i = 2:length(returns)
                sig = signals(i-1);
                
                cost = 0;
                if sig ~= position
                    % Apply transaction fee + execution slippage at trade entry/exit
                    cost = (obj.TransactionFee + obj.SlippageRate) * equity(i-1);
                end
                
                position = sig;
                
                grossNewEquity = equity(i-1) * (1 + position * returns(i));
                netNewEquity = grossNewEquity - cost;
                
                if netNewEquity <= 0 || ~isfinite(netNewEquity)
                    netNewEquity = 0;
                end
                
                equity(i) = netNewEquity;
                
                if equity(i-1) > 0
                    strategyReturns(i) = (equity(i) - equity(i-1)) / equity(i-1);
                else
                    strategyReturns(i) = 0;
                end
                if ~isfinite(strategyReturns(i))
                    strategyReturns(i) = 0;
                end
            end
            
            metrics = obj.computeMetrics(equity, strategyReturns, position);
            obj.logToDatabase(metrics, modelId, strategyName);
        end
        
        function metrics = computeMetrics(obj, equity, strategyReturns, finalPosition)
            metrics = struct();
            metrics.TotalReturn = (equity(end) - obj.InitialCapital) / obj.InitialCapital;
            
            N = obj.AnnualizationFactor; 
            
            years = length(equity) / N;
            if years > 0 && equity(end) > 0
                metrics.CAGR = (equity(end) / obj.InitialCapital)^(1/years) - 1;
            else
                metrics.CAGR = 0;
            end
            
            riskFreeRate = 0.02 / N;
            excessReturns = strategyReturns - riskFreeRate;
            if std(excessReturns) ~= 0 && ~isnan(std(excessReturns))
                metrics.SharpeRatio = sqrt(N) * mean(excessReturns) / std(excessReturns);
            else
                metrics.SharpeRatio = 0;
            end
            
            downside = excessReturns(excessReturns < 0);
            if ~isempty(downside) && std(downside) ~= 0 && ~isnan(std(downside))
                metrics.SortinoRatio = sqrt(N) * mean(excessReturns) / std(downside);
            else
                metrics.SortinoRatio = 0;
            end
            
            peaks = cummax(equity);
            drawdowns = (peaks - equity) ./ max(peaks, 1);
            metrics.MaxDrawdown = max(drawdowns);
            
            if metrics.MaxDrawdown > 0
                metrics.CalmarRatio = metrics.CAGR / metrics.MaxDrawdown;
            else
                metrics.CalmarRatio = 0;
            end
            
            metrics.VaR = prctile(strategyReturns, 5);
            metrics.CVaR = mean(strategyReturns(strategyReturns <= metrics.VaR));
            if ~isfinite(metrics.CVaR), metrics.CVaR = 0; end
            
            metrics.FinalBTCWeight = abs(finalPosition);
            metrics.FinalCashWeight = 1 - abs(finalPosition);
        end
        
        function logToDatabase(obj, metrics, modelId, strategyName)
            conn = DataIngestion.getDbConnection();
            if ~isempty(conn) && isopen(conn)
                try
                    query = "INSERT INTO portfolio_performance (strategy_name, model_id, sharpe_ratio, sortino_ratio, max_drawdown, cagr, btc_weight, cash_weight) VALUES (?, ?, ?, ?, ?, ?, ?, ?);";
                    execute(conn, query, {strategyName, modelId, metrics.SharpeRatio, metrics.SortinoRatio, metrics.MaxDrawdown, metrics.CAGR, metrics.FinalBTCWeight, metrics.FinalCashWeight});
                catch e
                    Logger.error('Failed to log portfolio metrics: %s', e.message);
                end
                close(conn);
            end
        end
        
        function [bestWeights, maxSharpe, htmlPath] = optimizePortfolio(obj)
            % Seed is now controlled by the caller or initialized once
            % at the start of the function, but removed from inside
            % the loop if it was there. wait - rng should be here.
            % The test called this twice, each time rng was set. 
            % fmincon is deterministic? sqp might depend on start point.
            % Let me set a fixed RNG seed at top level or here if it
            % must be. Let's make it deterministic.
            rng(12345); 
            Logger.info('Initializing Mean-Variance Portfolio Optimizer (BTC/ETH/BNB/Cash)...');
            
            % 1. Fetch live prices from Binance API
            symbols = {'BTCUSDT', 'ETHUSDT', 'BNBUSDT'};
            pricesCell = {};
            
            for s = 1:length(symbols)
                url = sprintf('https://api.binance.com/api/v3/klines?symbol=%s&interval=1d&limit=180', symbols{s});
                try
                    % Fetch daily klines
                    response = webread(url, weboptions('Timeout', 8));
                    prices = zeros(length(response), 1);
                    for i = 1:length(response)
                        prices(i) = str2double(response{i}{5}); % Close price is at index 5
                    end
                    pricesCell{s} = prices;
                    Logger.success('Successfully loaded 180 days of daily prices for %s', symbols{s});
                catch ME
                    Logger.error('Failed to fetch %s from Binance: %s. Fail-closed policy: aborting optimization.', symbols{s}, ME.message);
                    error('PortfolioSimulator:BinanceOutage', 'Production optimization requires live/historical Binance data and cannot proceed with simulated fallback prices: %s', ME.message);
                end
            end
            
            % Align lengths
            minL = min(cellfun(@length, pricesCell));
            R = zeros(minL - 1, 4); % BTC, ETH, BNB, Cash
            for s = 1:3
                p = pricesCell{s}(end-minL+1:end);
                R(:, s) = diff(p) ./ p(1:end-1);
            end
            R(:, 4) = 0; % Cash daily return is 0
            
            % 2. Calculate MPT Metrics
            meanR = mean(R);
            covR = cov(R);
            
            % 3. Deterministic Optimization for Efficient Frontier
            % Constraints: sum(w) = 1, 0 <= w <= 1
            Aeq = ones(1, 4);
            beq = 1;
            lb = zeros(1, 4);
            ub = ones(1, 4);
            x0 = [0.25 0.25 0.25 0.25];
            options = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp');

            % Maximize Sharpe Ratio (Minimize negative Sharpe) — 365 days/year for crypto.
            N = 365;
            objFunc = @(w) -(w * meanR' * N) / (sqrt(w * covR * w') * sqrt(N));
            bestWeights = fmincon(objFunc, x0, [], [], Aeq, beq, lb, ub, [], options);
            maxSharpe = -objFunc(bestWeights);
            bestRet = bestWeights * meanR' * N;
            bestVol = sqrt(bestWeights * covR * bestWeights') * sqrt(N);
            
            % Minimize Variance
            varFunc = @(w) w * covR * w';
            minVolWeights = fmincon(varFunc, x0, [], [], Aeq, beq, lb, ub, [], options);
            minVol = sqrt(minVolWeights * covR * minVolWeights') * sqrt(N);
            minVolRet = minVolWeights * meanR' * N;
            
            % Maximize Return
            retFunc = @(w) -(w * meanR' * N);
            maxRetWeights = fmincon(retFunc, x0, [], [], Aeq, beq, lb, ub, [], options);
            maxRet = -retFunc(maxRetWeights);
            maxRetVol = sqrt(maxRetWeights * covR * maxRetWeights') * sqrt(N);
            maxRetSharpe = maxRet / maxRetVol;
            
            % 4. Generate HTML Report
            reportsDir = fullfile(pwd, 'reports');
            if ~exist(reportsDir, 'dir'), mkdir(reportsDir); end
            htmlPath = fullfile(reportsDir, 'PortfolioOptimizationReport.html');
            
            fid = fopen(htmlPath, 'w');
            fprintf(fid, '<!DOCTYPE html><html><head><title>Portfolio Optimization Report</title>');
            fprintf(fid, '<style>body{font-family:Arial,sans-serif;margin:40px;background-color:#0b0c10;color:#c5c6c7;} ');
            fprintf(fid, 'h1{color:#66fcf1;} h2{color:#45a29e;border-bottom:1px solid #1f2833;padding-bottom:10px;} ');
            fprintf(fid, '.card{background-color:#1f2833;border-radius:8px;padding:20px;margin-bottom:20px;} ');
            fprintf(fid, 'table{border-collapse:collapse;width:100%%;margin-top:10px;} ');
            fprintf(fid, 'th,td{border:1px solid #2f3e46;padding:10px;text-align:left;} ');
            fprintf(fid, 'th{background-color:#111;color:#66fcf1;} .best{color:#66fcf1;font-weight:bold;}</style></head><body>');
            
            fprintf(fid, '<h1>📊 SentinelCrypto Portfolio Optimization Report 📊</h1>');
            fprintf(fid, '<p>Mathematical asset allocation utilizing Modern Portfolio Theory (MPT) with daily kline data.</p>');
            
            fprintf(fid, '<div class="card"><h2>🏆 Optimal Allocation (Max Sharpe Ratio)</h2>');
            fprintf(fid, '<table><tr><th>Asset</th><th>Optimal Weight</th></tr>');
            assets = {'Bitcoin (BTC)', 'Ethereum (ETH)', 'Binance Coin (BNB)', 'Cash (USD)'};
            for s = 1:4
                fprintf(fid, '<tr><td>%s</td><td class="best">%.2f%%</td></tr>', assets{s}, bestWeights(s)*100);
            end
            fprintf(fid, '</table>');
            fprintf(fid, '<p><strong>Annualized Expected Return:</strong> %.2f%%<br>', bestRet*100);
            fprintf(fid, '<strong>Annualized Volatility:</strong> %.2f%%<br>', bestVol*100);
            fprintf(fid, '<strong>Max Sharpe Ratio:</strong> %.3f</p></div>', maxSharpe);
            
            fprintf(fid, '<div class="card"><h2>⚖️ Alternative Portfolios Comparison</h2><table>');
            fprintf(fid, '<tr><th>Strategy</th><th>BTC Weight</th><th>ETH Weight</th><th>BNB Weight</th><th>Cash Weight</th><th>Exp. Return</th><th>Volatility</th><th>Sharpe</th></tr>');
            
            % Max Sharpe Row
            fprintf(fid, '<tr><td class="best">Max Sharpe (Optimal)</td><td>%.1f%%</td><td>%.1f%%</td><td>%.1f%%</td><td>%.1f%%</td><td>%.2f%%</td><td>%.2f%%</td><td>%.3f</td></tr>', ...
                bestWeights(1)*100, bestWeights(2)*100, bestWeights(3)*100, bestWeights(4)*100, bestRet*100, bestVol*100, maxSharpe);
            
            % Min Variance Row
            fprintf(fid, '<tr><td>Minimum Variance</td><td>%.1f%%</td><td>%.1f%%</td><td>%.1f%%</td><td>%.1f%%</td><td>%.2f%%</td><td>%.2f%%</td><td>%.3f</td></tr>', ...
                minVolWeights(1)*100, minVolWeights(2)*100, minVolWeights(3)*100, minVolWeights(4)*100, minVolRet*100, minVol*100, minVolRet/minVol);
                
            % Max Return Row
            fprintf(fid, '<tr><td>Maximum Return</td><td>%.1f%%</td><td>%.1f%%</td><td>%.1f%%</td><td>%.1f%%</td><td>%.2f%%</td><td>%.2f%%</td><td>%.3f</td></tr>', ...
                maxRetWeights(1)*100, maxRetWeights(2)*100, maxRetWeights(3)*100, maxRetWeights(4)*100, maxRet*100, maxRetVol*100, maxRetSharpe);
                
            fprintf(fid, '</table></div>');
            
            fprintf(fid, '<p><i>Generated on: %s</i></p></body></html>', char(datetime('now')));
            fclose(fid);
            
            Logger.success('Portfolio Optimization Report generated at reports/PortfolioOptimizationReport.html');
        end
    end
end
