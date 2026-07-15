%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef MarketDataDownloader
    % MarketDataDownloader Automatically retrieves historical BTC data
    % Uses Binance (Primary) and CoinGecko (Fallback) with incremental updates.
    
    properties (Constant)
        BINANCE_API_URL = 'https://api.binance.com/api/v3/klines';
        COINGECKO_API_URL = 'https://api.coingecko.com/api/v3/coins/bitcoin/ohlc';
    end
    
    methods (Static)
        function df = updateMarketData(timeframe)
            % updateMarketData Incremental update for a given timeframe
            if nargin < 1
                timeframe = '1h';
            end
            
            Logger.info('Starting incremental market data update for %s', timeframe);
            
            % 1. Determine last downloaded timestamp
            lastTimestamp = MarketDataDownloader.getLastTimestamp(timeframe);
            
            if isempty(lastTimestamp)
                Logger.info('No existing data found. Starting full historical download.');
                % Fetch maximum available depending on API limits
                startTime = datetime(2017,1,1, 'TimeZone', 'UTC');
            else
                startTime = lastTimestamp;
                Logger.info('Found existing data. Updating from %s', char(startTime));
            end
            
            % 2. Download Data (with Failover)
            try
                df = MarketDataDownloader.fetchFromBinance(timeframe, startTime);
            catch e
                Logger.warn('Binance API failed: %s. Falling back to CoinGecko.', e.message);
                try
                    df = MarketDataDownloader.fetchFromCoinGecko(timeframe, startTime);
                catch e2
                    Logger.error('All data providers failed. %s', e2.message);
                    error('Data download failed.');
                end
            end
            
            % 3. Validate Candles
            df = MarketDataDownloader.validateCandles(df);
            
            % 4. Save to Cache and Database
            if ~isempty(df)
                MarketDataDownloader.saveToParquet(df, timeframe);
                MarketDataDownloader.saveToDatabase(df, timeframe);
                Logger.success('Market data successfully updated (%d new candles).', height(df));
            else
                Logger.info('Data is already up to date.');
            end
        end
        
        function df = fetchFromBinance(timeframe, startTime)
            % Binance limits to 1000 candles per request
            endTime = datetime('now', 'TimeZone', 'UTC');
            
            % Map timeframe
            intervals = containers.Map({'1m','5m','15m','1h','4h','1d'}, ...
                                     {'1m','5m','15m','1h','4h','1d'});
            
            if ~isKey(intervals, timeframe)
                error('Unsupported timeframe for Binance: %s', timeframe);
            end
            
            startMs = posixtime(startTime) * 1000;
            endMs = posixtime(endTime) * 1000;
            
            url = sprintf('%s?symbol=BTCUSDT&interval=%s&startTime=%d&endTime=%d&limit=1000', ...
                MarketDataDownloader.BINANCE_API_URL, intervals(timeframe), uint64(startMs), uint64(endMs));
                
            options = weboptions('Timeout', 15);
            data = webread(url, options);
            
            if isempty(data)
                df = timetable();
                return;
            end
            
            % Parse Data
            % Binance format: [OpenTime, Open, High, Low, Close, Volume, CloseTime, QuoteAssetVolume, Trades, TakerBuyBase, TakerBuyQuote, Ignore]
            numCandles = length(data);
            timestamps = datetime(zeros(numCandles, 1), 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
            opens = zeros(numCandles, 1);
            highs = zeros(numCandles, 1);
            lows = zeros(numCandles, 1);
            closes = zeros(numCandles, 1);
            volumes = zeros(numCandles, 1);
            
            for i = 1:numCandles
                row = data{i};
                timestamps(i) = datetime(row{1}/1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
                opens(i) = str2double(row{2});
                highs(i) = str2double(row{3});
                lows(i) = str2double(row{4});
                closes(i) = str2double(row{5});
                volumes(i) = str2double(row{6});
            end
            
            df = timetable(timestamps, opens, highs, lows, closes, volumes, ...
                'VariableNames', {'Open', 'High', 'Low', 'Close', 'Volume'});
        end
        
        function df = fetchFromCoinGecko(timeframe, startTime)
            % CoinGecko has different limits and formats
            % For simplicity in this failover, we fetch the max allowed days
            days = 'max';
            url = sprintf('%s?vs_currency=usd&days=%s', MarketDataDownloader.COINGECKO_API_URL, days);
            
            options = weboptions('Timeout', 15);
            data = webread(url, options);
            
            if isempty(data)
                df = timetable();
                return;
            end
            
            % Format: [Time, Open, High, Low, Close]
            numCandles = length(data);
            timestamps = datetime(zeros(numCandles, 1), 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
            opens = zeros(numCandles, 1);
            highs = zeros(numCandles, 1);
            lows = zeros(numCandles, 1);
            closes = zeros(numCandles, 1);
            volumes = zeros(numCandles, 1); % CoinGecko OHLC doesn't provide volume directly in this endpoint
            
            for i = 1:numCandles
                row = data{i};
                ts = datetime(row(1)/1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
                timestamps(i) = ts;
                opens(i) = row(2);
                highs(i) = row(3);
                lows(i) = row(4);
                closes(i) = row(5);
            end
            
            df = timetable(timestamps, opens, highs, lows, closes, volumes, ...
                'VariableNames', {'Open', 'High', 'Low', 'Close', 'Volume'});
                
            % Filter out data before startTime
            df = df(df.Time > startTime, :);
        end
        
        function df = validateCandles(df)
            if isempty(df)
                return;
            end
            % Ensure no NaNs in core price data
            df = rmmissing(df, 'DataVariables', {'Open', 'High', 'Low', 'Close'});
            % Ensure High >= Low
            valid = (df.High >= df.Low) & (df.High >= df.Open) & (df.High >= df.Close) & (df.Low <= df.Open) & (df.Low <= df.Close);
            if any(~valid)
                Logger.warn('Filtered %d invalid candles (e.g., High < Low).', sum(~valid));
                df = df(valid, :);
            end
            % Sort by time
            df = sortrows(df, 'Time');
        end
        
        function lastTime = getLastTimestamp(timeframe)
            % Check local parquet cache
            cachePath = fullfile(pwd, 'data', 'market', 'btc', timeframe, 'historical.parquet');
            if exist(cachePath, 'file')
                info = parquetinfo(cachePath);
                % A full read just to get the last time is expensive, so we might want to store metadata later.
                % For now, read the tail
                % In MATLAB R2022b+, parquetread supports partial reading, but we'll read it all for simplicity if small.
                try
                    temp = parquetread(cachePath);
                    if ~isempty(temp)
                        lastTime = max(temp.Time);
                        return;
                    end
                catch
                    % Ignore error if file is corrupted
                end
            end
            lastTime = [];
        end
        
        function saveToParquet(df, timeframe)
            cacheDir = fullfile(pwd, 'data', 'market', 'btc', timeframe);
            if ~exist(cacheDir, 'dir')
                mkdir(cacheDir);
            end
            
            cachePath = fullfile(cacheDir, 'historical.parquet');
            if exist(cachePath, 'file')
                % Append (read old, merge, save)
                oldDf = parquetread(cachePath);
                % Convert to timetable if it was saved as table
                if istable(oldDf) && ismember('Time', oldDf.Properties.VariableNames)
                    oldDf = table2timetable(oldDf, 'RowTimes', 'Time');
                end
                merged = [oldDf; df];
                merged = unique(merged);
                parquetwrite(cachePath, merged);
            else
                parquetwrite(cachePath, df);
            end
        end
        
        function saveToDatabase(df, timeframe)
            dbUser = ConfigManager.getValue('DB_USER');
            dbPass = ConfigManager.getValue('DB_PASSWORD');
            if isempty(dbUser) || isempty(dbPass)
                % Skip DB if not configured
                return;
            end
            
            % Placeholder for PostgreSQL INSERT logic
            % We will wire up DataIngestion.m to handle the SQL connection
            Logger.debug('Data ready for PostgreSQL ingestion (%d rows).', height(df));
        end
    end
end
