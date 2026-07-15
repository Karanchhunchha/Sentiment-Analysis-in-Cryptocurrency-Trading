%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef MacroEngine
    % MacroEngine fetches live breaking news from the Alpha Vantage API
    % to determine fundamental macroeconomic sentiment (Bearish/Bullish) and
    % adjust the trading algorithm's bias and risk/reward.
    
    properties
        ApiUrl = 'https://www.alphavantage.co/query?function=NEWS_SENTIMENT&tickers=CRYPTO:BTC&limit=10&apikey=%s';
        ApiKey = 'demo'; % Will be loaded from .env
        BullishKeywords = ["CPI", "cut", "peace", "squeeze", "liquidated", "etf", "inflow", "pump", "breakthrough", "bullish"];
        BearishKeywords = ["PPI", "hike", "war", "crash", "sec", "sued", "hack", "inflation", "hotter", "outflow", "bearish"];
    end
    
    methods
        function obj = MacroEngine()
            % Load API key from environment configuration
            obj.loadConfig();
        end
        
        function loadConfig(obj)
            envFile = fullfile('configs', '.env');
            if exist(envFile, 'file')
                lines = readlines(envFile);
                for i = 1:length(lines)
                    str = strtrim(lines(i));
                    if startsWith(str, 'ALPHAVANTAGE_API_KEY=')
                        parts = split(str, '=');
                        obj.ApiKey = strtrim(parts(2));
                    end
                end
            else
                Logger.warning('No .env file found. MacroEngine will use demo API key.');
            end
        end
        
        function [bias, summary] = fetchLatestMacroBias(obj)
            try
                % Fetch live JSON data from Alpha Vantage News & Sentiment API
                url = sprintf(obj.ApiUrl, obj.ApiKey);
                options = weboptions('Timeout', 5, 'ContentType', 'json');
                data = webread(url, options);
                
                bullishScore = 0;
                bearishScore = 0;
                
                if isfield(data, 'feed') && ~isempty(data.feed)
                    feed = data.feed;
                    % Process top 10 articles
                    for i = 1:min(10, length(feed))
                        article = feed(i);
                        title = article.title;
                        
                        % Also use Alpha Vantage's built-in AI sentiment score
                        if isfield(article, 'overall_sentiment_score')
                            aiScore = article.overall_sentiment_score;
                            if aiScore > 0.15; bullishScore = bullishScore + 1.5; end
                            if aiScore < -0.15; bearishScore = bearishScore + 1.5; end
                        end
                        
                        % Secondary Keyword Matching
                        titleLower = lower(title);
                        for k = 1:length(obj.BullishKeywords)
                            if contains(titleLower, lower(obj.BullishKeywords(k)))
                                bullishScore = bullishScore + 1;
                            end
                        end
                        
                        for k = 1:length(obj.BearishKeywords)
                            if contains(titleLower, lower(obj.BearishKeywords(k)))
                                bearishScore = bearishScore + 1;
                            end
                        end
                    end
                else
                    % Fallback to simulated neutral if API limit reached or error
                    bias = 0;
                    summary = 'Macro Data: NEUTRAL (0.00) - No significant fundamental drivers detected.';
                    return;
                end
                
                % Normalize Score between -1 and 1
                totalHits = bullishScore + bearishScore;
                if totalHits == 0
                    bias = 0;
                    summary = 'Macro Data: Neutral (No significant economic drivers detected).';
                else
                    bias = (bullishScore - bearishScore) / totalHits;
                    
                    if bias > 0.5
                        summary = sprintf('Macro Data: EXTREME BULLISH (+%.2f) - High probability of short squeeze or rate relief.', bias);
                    elseif bias > 0
                        summary = sprintf('Macro Data: BULLISH (+%.2f) - Favorable economic tailwinds.', bias);
                    elseif bias < -0.5
                        summary = sprintf('Macro Data: EXTREME BEARISH (%.2f) - High inflation or regulatory fear detected.', bias);
                    else
                        summary = sprintf('Macro Data: BEARISH (%.2f) - Macro headwinds applying downward pressure.', bias);
                    end
                end
                
            catch ME
                bias = 0;
                summary = ['Macro Data Offline (Network Error): ', ME.message];
            end
        end
    end
end
