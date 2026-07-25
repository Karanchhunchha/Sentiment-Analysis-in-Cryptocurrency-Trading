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
    % "Use a Large Language Model via MATLAB API to retrieve features"
    
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
            
            Logger.info('Extracting features using LLM REST API for %d samples...', numSamples);
            
            url = 'http://localhost:11434/api/generate'; % Fallback to local Ollama instance
            options = weboptions('HeaderFields', {'Content-Type', 'application/json'}, 'Timeout', 5);
            
            for i = 1:numSamples
                txt = char(textData(i));
                
                % Design the prompt for feature extraction
                prompt = sprintf("Analyze the following cryptocurrency text and return a single number between -1.0 (extreme fear/bearish) and 1.0 (extreme greed/bullish). Do not include any other text, just the number. Text: '%s'", txt);
                body = struct('model', 'llama3', 'prompt', prompt, 'stream', false);
                
                try
                    % Query the LLM REST API
                    response = webwrite(url, body, options);
                    
                    % Parse JSON response
                    if isfield(response, 'response')
                        responseText = response.response;
                    elseif isstruct(response) && isfield(response, 'choices')
                        responseText = response.choices(1).message.content;
                    else
                        responseText = char(response);
                    end
                    
                    % Parse the numerical score
                    score = str2double(strtrim(responseText));
                    if isnan(score)
                        features(i) = 0; % Neutral fallback if parsing fails
                    else
                        features(i) = score;
                    end
                catch ME
                    % Print explicit warning instead of crashing
                    fprintf('[WARN] LLM REST API call failed for sample %d: %s\n', i, ME.message);
                    
                    % Log the exception directly to log file
                    [classDir, ~, ~] = fileparts(mfilename('fullpath'));
                    [srcDir, ~, ~] = fileparts(classDir);
                    [rootDir, ~, ~] = fileparts(srcDir);
                    logFile = fullfile(rootDir, 'evidence', 'llm_feature_test_log.txt');
                    logDir = fileparts(logFile);
                    if ~exist(logDir, 'dir'), mkdir(logDir); end
                    fid = fopen(logFile, 'a');
                    if fid ~= -1
                        fprintf(fid, '[%s] [ERROR] LLM REST API call failed for sample %d: %s\n', ...
                            datestr(now, 'yyyy-mm-dd HH:MM:SS'), i, ME.message);
                        fclose(fid);
                    end
                    
                    features(i) = 0; % Fallback score to prevent system crash
                end
            end
            
            Logger.success('LLM Feature Extraction Complete.');
        end
    end
end
