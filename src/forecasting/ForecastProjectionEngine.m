classdef ForecastProjectionEngine < handle
    % ForecastProjectionEngine Generates multi-horizon projected paths
    
    properties (Access = private)
        ConfidenceEng
    end
    
    methods
        function obj = ForecastProjectionEngine(confEngine)
            if nargin < 1
                obj.ConfidenceEng = ConfidenceEngine();
            else
                obj.ConfidenceEng = confEngine;
            end
        end
        
        function [expectedPath, upConf, dnConf, metrics, sourceStruct] = project(obj, currentPrice, oneStepPred, volatility, signal, currentConfidence)
            % Projects a single-step prediction into a multi-step forecast
            
            horizons = VisualizationConfig.ForecastHorizons.Steps;
            predSteps = max(horizons);
            
            if isnan(oneStepPred)
                expectedPath = NaN(predSteps, 1);
                upConf = NaN(predSteps, 1);
                dnConf = NaN(predSteps, 1);
                metrics = struct('AdaptiveThreshold', 60, 'ProjectionConfidence', 0, 'ProjectionReliability', 0, 'ProjectionDrift', 0);
                sourceStruct = struct();
                return;
            end
            
            % Generate expected path (drift-based for now, until multi-output model is ready)
            % This explicitly models a projection, NOT a true multi-step model output
            expectedPath = zeros(predSteps, 1);
            
            % First step is the actual model prediction
            expectedPath(1) = oneStepPred;
            
            % Compute the inferred drift from the first step
            driftPerStep = (oneStepPred - currentPrice) / currentPrice;
            
            % Project remaining steps
            for i = 2:predSteps
                % Dampen drift over time (mean reversion tendency)
                dampening = exp(-0.1 * i);
                expectedPath(i) = expectedPath(i-1) * (1 + driftPerStep * dampening);
            end
            
            % Delegate confidence calculation to ConfidenceEngine
            [upConf, dnConf, metrics] = obj.ConfidenceEng.calculateConfidence(expectedPath, volatility, currentConfidence);
            
            % Tag explicitly
            sourceStruct = struct(...
                'ModelPrediction', true, ...
                'Projection', true, ...
                'ConfidenceMethod', 'GaussianSigma', ...
                'ProjectionVersion', 'v1.0' ...
            );
        end
    end
end
