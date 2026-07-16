classdef ConfidenceEngine < handle
    % ConfidenceEngine Generates statistical confidence cones and quality metrics
    
    properties (Access = private)
        ConfidenceHistory = []
    end
    
    methods
        function obj = ConfidenceEngine()
        end
        
        function [upperConf, lowerConf, metrics] = calculateConfidence(obj, expectedPath, volatility, currentConfidence)
            % Calculates the expanding confidence cone over the projected path
            
            steps = length(expectedPath);
            
            % Expanding sigma based on square root of time
            sigma = volatility * sqrt(1:steps)';
            
            upperConf = expectedPath + sigma;
            lowerConf = expectedPath - sigma;
            
            % Update history
            if isempty(currentConfidence) || isnan(currentConfidence)
                currentConfidence = 0;
            end
            
            obj.ConfidenceHistory = [obj.ConfidenceHistory; currentConfidence];
            if length(obj.ConfidenceHistory) > 100
                obj.ConfidenceHistory(1) = []; % Keep last 100
            end
            
            % Calculate adaptive threshold
            if length(obj.ConfidenceHistory) > 5
                adaptiveThreshold = max(60, mean(obj.ConfidenceHistory) - std(obj.ConfidenceHistory));
            else
                adaptiveThreshold = 60; % Default minimum
            end
            
            % Compute forecast quality metrics
            % Drift is simplified as the annualized or step-based difference
            if steps > 1
                drift = ((expectedPath(end) - expectedPath(1)) / expectedPath(1)) * 100;
            else
                drift = 0;
            end
            
            % Reliability is a function of volatility vs price
            reliability = max(0, min(100, 100 - (volatility / expectedPath(1) * 10000)));
            
            metrics = struct(...
                'AdaptiveThreshold', adaptiveThreshold, ...
                'ProjectionConfidence', currentConfidence * 100, ...
                'ProjectionReliability', reliability, ...
                'ProjectionDrift', drift ...
            );
        end
        
        function history = getConfidenceHistory(obj)
            history = obj.ConfidenceHistory;
        end
    end
end
