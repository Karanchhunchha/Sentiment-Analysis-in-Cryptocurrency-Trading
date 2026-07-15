%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef PortfolioSimulator
%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
    % PortfolioSimulator Backtests strategy and computes risk metrics
    
    properties
        InitialCapital = 10000;
        TransactionFee = 0.001; % 0.1% Binance tier
    end
    
    methods
        function obj = PortfolioSimulator(initialCapital)
            if nargin > 0
                obj.InitialCapital = initialCapital;
            end
        end
        
        function metrics = runSimulation(obj, priceData, predictions, modelId, strategyName)
            % Compute equity curve based on predictions (1 = Long, -1 = Short, 0 = Hold)
            returns = diff(priceData) ./ priceData(1:end-1);
            returns = [0; returns]; % align length
            
            equity = zeros(length(returns), 1);
            equity(1) = obj.InitialCapital;
            
            position = 0; 
            
            for i = 2:length(returns)
                % Execute trade based on previous day prediction
                sig = predictions(i-1);
                
                % Transaction cost if position changes
                if sig ~= position
                    cost = obj.TransactionFee * equity(i-1);
                    equity(i-1) = equity(i-1) - cost;
                end
                
                position = sig;
                
                % Update equity
                dailyRet = position * returns(i);
                equity(i) = equity(i-1) * (1 + dailyRet);
            end
            
            metrics = obj.computeMetrics(equity, returns, position);
            
            % Log to DB
            obj.logToDatabase(metrics, modelId, strategyName);
        end
        
        function metrics = computeMetrics(obj, equity, returns, finalPosition)
            metrics = struct();
            metrics.TotalReturn = (equity(end) - obj.InitialCapital) / obj.InitialCapital;
            
            % Annualization factor (assuming daily data for this example)
            N = 365; 
            
            % CAGR
            years = length(equity) / N;
            if years > 0
                metrics.CAGR = (equity(end) / obj.InitialCapital)^(1/years) - 1;
            else
                metrics.CAGR = 0;
            end
            
            % Sharpe
            dailyRiskFreeRate = 0.02 / N;
            excessReturns = returns - dailyRiskFreeRate;
            if std(excessReturns) ~= 0
                metrics.SharpeRatio = sqrt(N) * mean(excessReturns) / std(excessReturns);
            else
                metrics.SharpeRatio = 0;
            end
            
            % Sortino
            downside = excessReturns(excessReturns < 0);
            if ~isempty(downside) && std(downside) ~= 0
                metrics.SortinoRatio = sqrt(N) * mean(excessReturns) / std(downside);
            else
                metrics.SortinoRatio = 0;
            end
            
            % Max Drawdown
            peaks = cummax(equity);
            drawdowns = (peaks - equity) ./ peaks;
            metrics.MaxDrawdown = max(drawdowns);
            
            % Calmar
            if metrics.MaxDrawdown > 0
                metrics.CalmarRatio = metrics.CAGR / metrics.MaxDrawdown;
            else
                metrics.CalmarRatio = 0;
            end
            
            % Value at Risk (95%)
            metrics.VaR = prctile(returns, 5);
            
            % Conditional VaR (Expected Shortfall)
            metrics.CVaR = mean(returns(returns <= metrics.VaR));
            
            metrics.FinalBTCWeight = abs(finalPosition);
            metrics.FinalCashWeight = 1 - abs(finalPosition);
        end
        
        function logToDatabase(obj, metrics, modelId, strategyName)
            conn = DataIngestion.getDbConnection();
            if ~isempty(conn) && isopen(conn)
                try
                    query = sprintf(...
                        "INSERT INTO portfolio_performance (strategy_name, model_id, sharpe_ratio, sortino_ratio, max_drawdown, cagr, btc_weight, cash_weight) " + ...
                        "VALUES ('%s', '%s', %f, %f, %f, %f, %f, %f);", ...
                        strategyName, modelId, metrics.SharpeRatio, metrics.SortinoRatio, metrics.MaxDrawdown, metrics.CAGR, metrics.FinalBTCWeight, metrics.FinalCashWeight);
                    execute(conn, query);
                catch e
                    Logger.error('Failed to log portfolio metrics: %s', e.message);
                end
                close(conn);
            end
        end
        
        function [bestWeights, maxSharpe, htmlPath] = optimizePortfolio(obj)
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
                    Logger.warn('Failed to fetch %s: %s. Generating simulated returns.', symbols{s}, ME.message);
                    % Generate a plausible price path using random walk
                    pricesCell{s} = cumprod(1 + 0.0005 + randn(180, 1) * 0.03) * 100;
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
            
            % 3. Monte Carlo Simulation for Efficient Frontier
            numPortfolios = 5000;
            allWeights = zeros(numPortfolios, 4);
            allReturns = zeros(numPortfolios, 1);
            allVols = zeros(numPortfolios, 1);
            allSharpes = zeros(numPortfolios, 1);
            
            for i = 1:numPortfolios
                w = rand(1, 4);
                w = w / sum(w);
                allWeights(i, :) = w;
                
                % Annualized Return & Volatility
                portRet = sum(w .* meanR) * 252;
                portVol = sqrt(w * covR * w') * sqrt(252);
                
                allReturns(i) = portRet;
                allVols(i) = portVol;
                if portVol > 0
                    allSharpes(i) = portRet / portVol;
                else
                    allSharpes(i) = 0;
                end
            end
            
            % Find optimal weights
            [maxSharpe, bestIdx] = max(allSharpes);
            bestWeights = allWeights(bestIdx, :);
            bestRet = allReturns(bestIdx);
            bestVol = allVols(bestIdx);
            
            % Find minimum variance portfolio
            [minVol, minVolIdx] = min(allVols);
            minVolWeights = allWeights(minVolIdx, :);
            minVolRet = allReturns(minVolIdx);
            
            % Find maximum return portfolio
            [maxRet, maxRetIdx] = max(allReturns);
            maxRetWeights = allWeights(maxRetIdx, :);
            maxRetVol = allVols(maxRetIdx);
            maxRetSharpe = allSharpes(maxRetIdx);
            
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
