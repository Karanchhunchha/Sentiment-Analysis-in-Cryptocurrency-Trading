%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef LLMFeatureExtractor
    % LLMFeatureExtractor: Uses Large Language Models via REST API
    % to retrieve features (e.g. sentiment scores, macro factors) to build time series models.
    
    properties
        IsAvailable = true
    end
    
    methods
        function obj = LLMFeatureExtractor()
            % Constructor: Initialize the LLM REST API client
            Logger.info('Initializing LLM Feature Extractor REST API client...');
            obj.IsAvailable = true;
        end
        
        function features = extractFeaturesFromText(obj, textData)
            % Extracts sentiment/macro features from a batch of text using the LLM REST API.
            
            numSamples = numel(textData);
            features = zeros(numSamples, 1);
            
            Logger.info('Extracting features using LLM/Sentiment REST API for %d samples...', numSamples);
            
            % Check API Key configuration
            apiKey = ConfigManager.getValue('ANTHROPIC_API_KEY');
            if isempty(apiKey) || strcmp(apiKey, 'your_anthropic_api_key_here') || startsWith(apiKey, 'placeholder')
                apiKey = getenv('ANTHROPIC_API_KEY');
            end
            
            isKeyConfigured = ~isempty(apiKey) && ~strcmp(apiKey, 'your_anthropic_api_key_here') && ~startsWith(apiKey, 'placeholder');
            
            if ~isKeyConfigured
                warning('SentinelCrypto:LLM:NoKey', 'LLM API key not configured. Set ANTHROPIC_API_KEY in configs/.env to enable LLM feature extraction. Returning neutral score.');
            end
            
            for i = 1:numSamples
                txt = char(textData(i));
                features(i) = 0.0000; % Default neutral score
                
                if isKeyConfigured
                    url = 'https://api.anthropic.com/v1/messages';
                    options = weboptions('HeaderFields', { ...
                        'x-api-key', apiKey; ...
                        'anthropic-version', '2023-06-01'; ...
                        'content-type', 'application/json' ...
                    }, 'Timeout', 10);
                    
                    prompt = sprintf('Analyze the sentiment of the following cryptocurrency text and return a single number between -1.0 (bearish) and 1.0 (bullish). Return ONLY the number, no explanation. Text: "%s"', txt);
                    body = struct(...
                        'model', 'claude-haiku-4-5-20251001', ...
                        'max_tokens', 10, ...
                        'messages', {{struct('role', 'user', 'content', prompt)}} ...
                    );
                    
                    try
                        response = webwrite(url, body, options);
                        if isfield(response, 'content')
                            if iscell(response.content)
                                responseText = response.content{1}.text;
                            else
                                responseText = response.content(1).text;
                            end
                            score = str2double(strtrim(responseText));
                            if ~isnan(score)
                                features(i) = score;
                            end
                        end
                    catch ME
                        fprintf('[WARN] Anthropic API failed (sample %d): %s\n', i, ME.message);
                    end
                end
            end
            
            Logger.success('LLM Feature Extraction Complete.');
        end
    end
end
