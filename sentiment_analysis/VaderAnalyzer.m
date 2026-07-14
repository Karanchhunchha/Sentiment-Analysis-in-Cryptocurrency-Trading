% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto

classdef VaderAnalyzer < handle
    % VADERANALYZER Computes sentiment using the VADER lexicon
    % Utilizes MATLAB's Text Analytics Toolbox native vaderSentimentScores
    
    methods
        function obj = VaderAnalyzer()
        end
        
        function score = analyze(obj, textData)
            % Ensure text is a string
            textStr = string(textData);
            
            % Use native Text Analytics Toolbox VADER scoring
            try
                % The vaderSentimentScores function returns a table with a 'Compound' column
                vs = vaderSentimentScores(textStr);
                score = vs.Compound;
            catch
                % Fallback if toolbox is unavailable or function fails
                disp('⚠️ Text Analytics Toolbox not found or VADER failed. Returning neutral score.');
                score = 0;
            end
        end
    end
end
