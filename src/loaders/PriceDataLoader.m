classdef PriceDataLoader < handle
    % PriceDataLoader Production data loader for SentinelCrypto.
    % Handles batch loading of historical data (e.g., btc.csv) and 
    % event-driven updates for live Binance data.
    
    properties
        Symbol
        Interval
        Data
        LiveTimer
        UpdateCallback
    end
    
    methods
        function obj = PriceDataLoader(symbol, interval)
            if nargin < 2; interval = '1h'; end
            if nargin < 1; symbol = 'BTCUSDT'; end
            
            obj.Symbol = symbol;
            obj.Interval = interval;
            obj.Data = table();
        end
        
        %% 1. Historical Batch Loader
        function data = loadHistoricalCSV(obj, filepath)
            Logger.info('Loading historical data from %s', filepath);
            if ~exist(filepath, 'file')
                error('PriceDataLoader:FileNotFound', 'CSV not found: %s', filepath);
            end
            
            % Read CSV
            opts = detectImportOptions(filepath);
            raw = readtable(filepath, opts);
            
            % Standardize column names (assuming Open, High, Low, Close, Volume)
            expectedVars = {'Open', 'High', 'Low', 'Close', 'Volume'};
            if ~all(ismember(expectedVars, raw.Properties.VariableNames))
                Logger.warning('CSV missing standard OHLCV columns. Check format.');
            end
            
            obj.Data = raw;
            data = obj.Data;
            Logger.success('Loaded %d historical candles.', height(obj.Data));
        end
        
        %% 2. Live Event-Driven Loader
        function startLiveStream(obj, callbackFunc)
            % Starts an asynchronous timer to fetch the latest candle
            % and triggers the callbackFunc (e.g., updating dashboard).
            
            if ~isempty(obj.LiveTimer) && isvalid(obj.LiveTimer)
                stop(obj.LiveTimer);
                delete(obj.LiveTimer);
            end
            
            obj.UpdateCallback = callbackFunc;
            
            % Parse interval to seconds (e.g., '5m' -> 300)
            pollPeriod = 300; % Default 5 minutes
            if contains(obj.Interval, 'm')
                pollPeriod = str2double(strrep(obj.Interval, 'm', '')) * 60;
            elseif contains(obj.Interval, 'h')
                pollPeriod = str2double(strrep(obj.Interval, 'h', '')) * 3600;
            end
            
            Logger.info('Starting Live Stream for %s (Polling every %d sec)', obj.Symbol, pollPeriod);
            
            obj.LiveTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', pollPeriod, ...
                'TimerFcn', @(~,~) obj.fetchLatestCandle());
            
            start(obj.LiveTimer);
            
            % Trigger first fetch immediately
            obj.fetchLatestCandle();
        end
        
        function stopLiveStream(obj)
            if ~isempty(obj.LiveTimer) && isvalid(obj.LiveTimer)
                stop(obj.LiveTimer);
                delete(obj.LiveTimer);
                Logger.info('Live stream stopped.');
            end
        end
    end
    
    methods (Access = private)
        function fetchLatestCandle(obj)
            try
                % Fetch latest closed candle from Binance REST API (Fast, <100ms)
                url = sprintf('https://api.binance.com/api/v3/klines?symbol=%s&interval=%s&limit=1', obj.Symbol, obj.Interval);
                options = weboptions('Timeout', 5);
                response = webread(url, options);
                
                if ~isempty(response)
                    newCandle = obj.parseBinanceResponse(response);
                    
                    % Append incrementally
                    obj.Data = [obj.Data; newCandle];
                    
                    % Trigger pipeline update
                    if ~isempty(obj.UpdateCallback)
                        obj.UpdateCallback(newCandle, obj.Data);
                    end
                end
            catch ME
                Logger.error('Failed to fetch live candle: %s', ME.message);
            end
        end
        
        function candleTable = parseBinanceResponse(~, rawJson)
            % Parses standard Binance kline JSON array into a MATLAB table
            row = rawJson{1};
            
            % Binance returns cells of strings/doubles
            openTime = datetime(row{1}/1000, 'ConvertFrom', 'posixtime');
            openP = str2double(row{2});
            highP = str2double(row{3});
            lowP  = str2double(row{4});
            closeP= str2double(row{5});
            vol   = str2double(row{6});
            
            candleTable = table(openTime, openP, highP, lowP, closeP, vol, ...
                'VariableNames', {'Date', 'Open', 'High', 'Low', 'Close', 'Volume'});
        end
    end
end
