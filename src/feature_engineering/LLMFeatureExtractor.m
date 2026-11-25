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
        
        function features = extractFeaturesFromText(~, textData)
            % Extracts sentiment/macro features from a batch of text using the LLM REST API.
            
            numSamples = numel(textData);
            features = zeros(numSamples, 1);
            
            Logger.info('Extracting features using LLM/Sentiment REST API for %d samples...', numSamples);
            
            % Check API Key configuration.
            % The key is read ONLY from the process environment or the
            % MATLAB secret store (setSecret/getSecret). It is deliberately
            % NOT read from the plaintext configs/.env file: a real key must
            % never sit in a plaintext file inside the repo tree.
            apiKey = getenv('ANTHROPIC_API_KEY');
            if isempty(apiKey)
                try
                    apiKey = getSecret('ANTHROPIC_API_KEY');
                catch
                    % getSecret unavailable (older MATLAB) or no secret
                    % stored under that name — treated as "not configured".
                    apiKey = '';
                end
                if ~ischar(apiKey) && ~isstring(apiKey)
                    apiKey = '';
                end
                apiKey = char(apiKey);
            end

            isKeyConfigured = ~isempty(apiKey) && ~strcmp(apiKey, 'your_anthropic_api_key_here') && ~startsWith(apiKey, 'placeholder');

            if ~isKeyConfigured
                error('SentinelCrypto:LLM:NoKey', ...
                    ['LLM API key not configured. Set the ANTHROPIC_API_KEY environment ' ...
                     'variable, or store the key in the MATLAB secret store with ' ...
                     'setSecret(''ANTHROPIC_API_KEY'', <key>), to enable LLM feature extraction. ' ...
                     'Plaintext configs/.env key loading was removed.']);
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
