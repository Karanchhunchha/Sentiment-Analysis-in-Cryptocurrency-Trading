%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto

classdef BinanceDataFetcher < handle
    % BINANCEDATAFETCHER Retrieves historical OHLCV data from Binance REST API
    % Generates indicators (RSI, MA) on the fly for model training.

    properties
        BaseURL = 'https://api.binance.com/api/v3/klines'
        Timeout = 30
    end
    
    methods
        function obj = BinanceDataFetcher()
        end
        
        function dataTable = fetchHistoricalData(obj, symbol, interval, limit)
            % fetchHistoricalData Pulls candles and returns a table with technical indicators
            disp('================================================');
            disp(['   🌐 SentinelCrypto Binance Fetcher (' interval ') 🌐   ']);
            disp('================================================');
            
            url = sprintf('%s?symbol=%s&interval=%s&limit=%d', obj.BaseURL, symbol, interval, limit);
            options = weboptions('Timeout', obj.Timeout, 'UserAgent', 'Mozilla/5.0');
            
            disp(['📥 Downloading ' num2str(limit) ' candles from Binance...']);
            
            try
                rawData = webread(url, options);
            catch
                error('❌ Failed to connect to Binance API.');
            end
            
            numRows = length(rawData);
            openPrices = zeros(numRows, 1);
            highPrices = zeros(numRows, 1);
            lowPrices = zeros(numRows, 1);
            closePrices = zeros(numRows, 1);
            volumes = zeros(numRows, 1);
            
            for i = 1:numRows
                row = rawData{i};
                openPrices(i) = str2double(row{2});
                highPrices(i) = str2double(row{3});
                lowPrices(i) = str2double(row{4});
                closePrices(i) = str2double(row{5});
                volumes(i) = str2double(row{6});
            end
            
            % Technical Indicators 
            ma10 = movmean(closePrices, [9 0]);
            ma20 = movmean(closePrices, [19 0]);
            vol_ma20 = movmean(volumes, [19 0]);
            
            % RSI Calculation (Wilder's Smoothing)
            rsi = zeros(numRows, 1);
            diffs = [0; diff(closePrices)];
            gains = max(0, diffs);
            losses = max(0, -diffs);
            
            avg_gain = mean(gains(2:15));
            avg_loss = mean(losses(2:15));
            for i = 15:numRows
                avg_gain = (avg_gain * 13 + gains(i)) / 14;
                avg_loss = (avg_loss * 13 + losses(i)) / 14;
                if avg_loss == 0
                    rsi(i) = 100;
                else
                    rsi(i) = 100 - (100 / (1 + avg_gain/avg_loss));
                end
            end
            rsi(1:14) = 50; % Default neutral RSI for warm-up period
            
            dataTable = table(openPrices, highPrices, lowPrices, closePrices, volumes, ...
                rsi, ma10, ma20, vol_ma20, ...
                'VariableNames', {'Open', 'High', 'Low', 'Close', 'Volume', 'RSI', 'MA10', 'MA20', 'Vol_MA20'});
            
            disp(['✅ Successfully processed ' num2str(numRows) ' data points.']);
        end
    end
end
