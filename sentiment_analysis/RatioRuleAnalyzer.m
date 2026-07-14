% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto

classdef RatioRuleAnalyzer < handle
    % RATIORULEANALYZER Computes sentiment using a simple positive/negative word ratio
    % This satisfies the explicit MathWorks Challenge requirement.
    
    properties
        PositiveLexicon
        NegativeLexicon
    end
    
    methods
        function obj = RatioRuleAnalyzer()
            % Simple built-in lexicon for ratio rule
            obj.PositiveLexicon = {'bullish', 'up', 'moon', 'buy', 'gain', 'profit', 'good', 'great', 'surge', 'pump', 'high', 'win', 'success'};
            obj.NegativeLexicon = {'bearish', 'down', 'crash', 'sell', 'loss', 'bad', 'terrible', 'drop', 'dump', 'low', 'fail', 'scam', 'fear'};
        end
        
        function score = analyze(obj, textData)
            % Returns a normalized score between -1 and 1
            textData = lower(string(textData));
            words = split(textData);
            
            posCount = sum(ismember(words, obj.PositiveLexicon));
            negCount = sum(ismember(words, obj.NegativeLexicon));
            
            total = posCount + negCount;
            
            if total == 0
                score = 0;
            else
                % Normalize to [-1, 1] range
                score = (posCount - negCount) / total;
            end
        end
    end
end
