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
            
            % Load API key from configs/.env or system environment
            apiKey = ConfigManager.getValue('ANTHROPIC_API_KEY');
            if isempty(apiKey) || strcmp(apiKey, 'your_anthropic_api_key_here')
                apiKey = getenv('ANTHROPIC_API_KEY');
            end
            
            for i = 1:numSamples
                txt = char(textData(i));
                success = false;
                
                % Option A: Try real Anthropic Messages API if key is present
                if ~isempty(apiKey) && ~startsWith(apiKey, 'placeholder')
                    url = 'https://api.anthropic.com/v1/messages';
                    options = weboptions('HeaderFields', { ...
                        'x-api-key', apiKey; ...
                        'anthropic-version', '2023-06-01'; ...
                        'content-type', 'application/json' ...
                    }, 'Timeout', 10);
                    
                    prompt = sprintf('Analyze the sentiment of the following cryptocurrency text and return a single number between -1.0 (bearish) and 1.0 (bullish). Return ONLY the number, no explanation. Text: "%s"', txt);
                    body = struct(...
                        'model', 'claude-3-haiku-20240307', ...
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
                                success = true;
                            end
                        end
                    catch ME
                        fprintf('[WARN] Anthropic API failed (sample %d): %s\n', i, ME.message);
                    end
                end
                
                % Option B: Fallback to real external Sentiment Classifier API if Anthropic fails or is not configured
                if ~success
                    try
                        url = 'http://text-processing.com/api/sentiment/';
                        res = webwrite(url, 'text', txt);
                        if isfield(res, 'probability')
                            % Map probabilities to a score between -1.0 and 1.0
                            posProb = res.probability.pos;
                            negProb = res.probability.neg;
                            features(i) = posProb - negProb;
                        else
                            features(i) = 0.0;
                        end
                    catch ME
                        fprintf('[WARN] Fallback Sentiment API failed (sample %d): %s\n', i, ME.message);
                        
                        % Log the exception directly to log file
                        [classDir, ~, ~] = fileparts(mfilename('fullpath'));
                        [srcDir, ~, ~] = fileparts(classDir);
                        [rootDir, ~, ~] = fileparts(srcDir);
                        logFile = fullfile(rootDir, 'evidence', 'llm_feature_test_log.txt');
                        logDir = fileparts(logFile);
                        if ~exist(logDir, 'dir'), mkdir(logDir); end
                        fid = fopen(logFile, 'a');
                        if fid ~= -1
                            fprintf(fid, '[%s] [ERROR] REST API calls failed: %s\n', ...
                                datestr(now, 'yyyy-mm-dd HH:MM:SS'), ME.message);
                            fclose(fid);
                        end
                        features(i) = 0; % Neutral fallback
                    end
                end
            end
            
            Logger.success('LLM Feature Extraction Complete.');
        end
    end
end
