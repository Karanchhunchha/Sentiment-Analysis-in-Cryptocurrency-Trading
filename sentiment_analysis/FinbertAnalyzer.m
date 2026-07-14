% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto

classdef FinbertAnalyzer < handle
    % FINBERTANALYZER Computes neural sentiment using ProsusAI/finbert
    % Utilizes MATLAB's Python integration (pyenv) to call HuggingFace transformers
    
    properties
        IsPythonAvailable = false;
        Pipeline % Python pipeline object
    end
    
    methods
        function obj = FinbertAnalyzer()
            try
                % Check if Python is loaded and transformers is available
                py.importlib.import_module('transformers');
                
                % Initialize the pipeline
                % py.transformers.pipeline('sentiment-analysis', model='ProsusAI/finbert')
                kwargs = pyargs('model', 'ProsusAI/finbert');
                obj.Pipeline = py.transformers.pipeline('sentiment-analysis', kwargs);
                
                obj.IsPythonAvailable = true;
                disp('✅ FinBERT Pipeline initialized via Python Integration.');
            catch ME
                disp('⚠️ Python transformers not found or pyenv misconfigured.');
                disp(ME.message);
                disp('⚠️ Falling back to simulated FinBERT scores for pipeline completion.');
                obj.IsPythonAvailable = false;
            end
        end
        
        function [score, confidence] = analyze(obj, textData)
            if obj.IsPythonAvailable
                try
                    % Call the python pipeline
                    result = cell(obj.Pipeline(string(textData)));
                    resultStruct = struct(result{1});
                    
                    label = char(resultStruct.label);
                    confidence = double(resultStruct.score);
                    
                    % Convert labels to standard [-1, 1] range
                    if strcmp(label, 'positive')
                        score = confidence;
                    elseif strcmp(label, 'negative')
                        score = -confidence;
                    else
                        score = 0; % neutral
                    end
                catch
                    score = 0;
                    confidence = 0.5;
                end
            else
                % Mock neural scoring if python env is not set up
                % Just to allow pipeline to run end-to-end
                score = (rand() * 2) - 1; 
                confidence = rand() * 0.5 + 0.5; % Random confidence [0.5, 1.0]
            end
        end
    end
end
