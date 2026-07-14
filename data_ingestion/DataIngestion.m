classdef DataIngestion
    methods (Static)
        function env = readEnv(envPath)
            % Reads env key-values from the .env configuration file
            if nargin < 1
                envPath = fullfile(pwd, 'configs', '.env');
            end
            env = containers.Map();
            if ~exist(envPath, 'file')
                warning('⚠️ Configuration file .env not found at %s. Using default settings.', envPath);
                return;
            end
            
            fid = fopen(envPath, 'r');
            while ~feof(fid)
                line = strtrim(fgetl(fid));
                if isempty(line) || startsWith(line, '#') || ~contains(line, '=')
                    continue;
                end
                tokens = split(line, '=');
                if numel(tokens) >= 2
                    key = strtrim(tokens{1});
                    val = strtrim(join(tokens(2:end), '='));
                    env(key) = val;
                end
            end
            fclose(fid);
        end
        
        function conn = getDbConnection()
            % Connects to the local PostgreSQL database using credentials in .env
            env = DataIngestion.readEnv();
            
            % Default fallbacks
            db_name = 'sentinelcrypto';
            db_user = 'postgres';
            db_pass = '';
            db_host = 'localhost';
            db_port = '5432';
            
            if isKey(env, 'DB_NAME'), db_name = env('DB_NAME'); end
            if isKey(env, 'DB_USER'), db_user = env('DB_USER'); end
            if isKey(env, 'DB_PASSWORD'), db_pass = env('DB_PASSWORD'); end
            if isKey(env, 'DB_HOST'), db_host = env('DB_HOST'); end
            if isKey(env, 'DB_PORT'), db_port = env('DB_PORT'); end
            
            try
                % Using Database Toolbox connection object
                conn = database(db_name, db_user, db_pass, 'Vendor', 'PostgreSQL', ...
                    'Server', db_host, 'PortNumber', str2double(db_port));
                
                if ~isempty(conn.Message)
                    error(conn.Message);
                end
            catch e
                warning('❌ Failed to connect to PostgreSQL. Reason: %s', e.message);
                conn = [];
            end
        end
        
        function syncLivePrices(symbol, interval, limit)
            if nargin < 3
                limit = 1000;
            end
            if nargin < 2
                interval = '1h';
            end
            if nargin < 1
                symbol = 'BTCUSDT';
            end
            
            % Use native MATLAB fetcher instead of Python
            addpath(fullfile(pwd, 'data_ingestion'));
            fetcher = BinanceDataFetcher();
            dataTable = fetcher.fetchHistoricalData(symbol, interval, limit);
            
            % Connect to DB
            conn = DataIngestion.getDbConnection();
            if isempty(conn) || ~isopen(conn)
                warning('Cannot sync to DB: DB Connection Failed.');
                return;
            end
            
            % Insert to DB
            disp('⏳ Syncing to PostgreSQL historical_prices table...');
            
            % For simplicity, mock the timestamp generation for the past N hours
            nowTime = datetime('now', 'TimeZone', 'UTC');
            
            for i = 1:height(dataTable)
                rowTime = nowTime - hours(height(dataTable) - i);
                timeStr = datestr(rowTime, 'yyyy-mm-dd HH:MM:SS');
                
                query = sprintf(...
                    "INSERT INTO historical_prices (timestamp, symbol, open_price, high_price, low_price, close_price, volume) " + ...
                    "VALUES ('%s', '%s', %f, %f, %f, %f, %f) " + ...
                    "ON CONFLICT (timestamp, symbol) DO NOTHING;", ...
                    timeStr, 'BTC', dataTable.Open(i), dataTable.High(i), dataTable.Low(i), dataTable.Close(i), dataTable.Volume(i));
                
                try
                    execute(conn, query);
                catch e
                end
            end
            
            disp('✅ Sync complete.');
            close(conn);
        end
        
        function priceTable = fetchPrices(symbol)
            % Fetches historical price data for a symbol from PostgreSQL
            if nargin < 1
                symbol = 'BTC';
            end
            
            conn = DataIngestion.getDbConnection();
            if isempty(conn) || ~isopen(conn)
                error('DB Connection Failed.');
            end
            
            query = sprintf("SELECT timestamp, open_price as Open, high_price as High, low_price as Low, close_price as Close, volume as Volume FROM historical_prices WHERE symbol = '%s' ORDER BY timestamp ASC;", symbol);
            priceTable = select(conn, query);
            close(conn);
        end
        
        function writeSentiment(timestamp, symbol, mlScore, vaderScore, ratioRuleScore, llmScore, llmConf)
            conn = DataIngestion.getDbConnection();
            if isempty(conn) || ~isopen(conn)
                return;
            end
            
            timeStr = datestr(timestamp, 'yyyy-mm-dd HH:MM:SS');
            query = sprintf(...
                "INSERT INTO sentiment_scores (timestamp, symbol, ml_score, vader_score, ratio_rule_score, llm_score, llm_confidence) " + ...
                "VALUES ('%s', '%s', %f, %f, %f, %f, %f) " + ...
                "ON CONFLICT (timestamp, symbol) DO UPDATE SET " + ...
                "ml_score = EXCLUDED.ml_score, vader_score = EXCLUDED.vader_score, " + ...
                "ratio_rule_score = EXCLUDED.ratio_rule_score, llm_score = EXCLUDED.llm_score, llm_confidence = EXCLUDED.llm_confidence;", ...
                timeStr, symbol, mlScore, vaderScore, ratioRuleScore, llmScore, llmConf);
            
            try
                execute(conn, query);
            catch e
                warning('❌ Error writing sentiment to PostgreSQL: %s', e.message);
            end
            close(conn);
        end
    end
end
