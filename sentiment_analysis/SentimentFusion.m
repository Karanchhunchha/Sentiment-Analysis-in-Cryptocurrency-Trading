% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto

classdef SentimentFusion < handle
    % SENTIMENTFUSION Dynamically fuses multiple sentiment models
    % Combines VADER lexicon, FinBERT neural scores, and Ratio-Rule.
    
    properties
        VaderAnalyzer
        FinbertAnalyzer
        RatioRuleAnalyzer
    end
    
    methods
        function obj = SentimentFusion()
            obj.VaderAnalyzer = VaderAnalyzer();
            obj.FinbertAnalyzer = FinbertAnalyzer();
            obj.RatioRuleAnalyzer = RatioRuleAnalyzer();
        end
        
        function [fusedScore, scores] = evaluate(obj, textData)
            % Returns the final fused score and a struct of all individual scores
            
            vaderScore = obj.VaderAnalyzer.analyze(textData);
            ratioScore = obj.RatioRuleAnalyzer.analyze(textData);
            [finbertScore, confidence] = obj.FinbertAnalyzer.analyze(textData);
            
            % Fusion Logic: Confidence Weighted Blending
            % If FinBERT is highly confident, it dominates the score.
            % If uncertain, we rely evenly on Lexicon + Ratio Rule + FinBERT.
            
            if confidence > 0.8
                % High neural confidence
                fusedScore = (finbertScore * 0.7) + (vaderScore * 0.2) + (ratioScore * 0.1);
            else
                % Edge case / low confidence: Equal weight fallback
                fusedScore = (finbertScore * 0.33) + (vaderScore * 0.33) + (ratioScore * 0.34);
            end
            
            % Return individual scores for logging/comparison
            scores = struct();
            scores.Vader = vaderScore;
            scores.RatioRule = ratioScore;
            scores.Finbert = finbertScore;
            scores.Confidence = confidence;
        end
    end
end
