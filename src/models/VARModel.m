classdef VARModel < handle
    % VARModel: Implements Vector Autoregression (VAR) for price changes and sentiment
    % using MATLAB's Econometrics Toolbox.
    
    properties
        NumLags
        ModelSpec
        EstimatedModel
        Variables
        FEVD
    end
    
    methods
        function obj = VARModel(numLags)
            if nargin < 1
                numLags = 2; % Default to VAR(2)
            end
            obj.NumLags = numLags;
            obj.Variables = {'PriceChange', 'Daily_Sentiment'};
        end
        
        function fit(obj, dataTable)
            % Fits a VAR model on the provided table containing 'Close' and 'Daily_Sentiment'
            Logger.info('Specifying and estimating VAR(%d) model...', obj.NumLags);
            
            % Compute price change (stationarity requirement for VAR)
            prices = dataTable.Close;
            priceChange = [0; diff(prices)];
            
            % Create endogenous matrix
            sentiment = dataTable.Daily_Sentiment;
            Y = [priceChange, sentiment];
            
            % Specify VAR model: 2 series (PriceChange, Sentiment), NumLags lags
            obj.ModelSpec = varm(2, obj.NumLags);
            obj.ModelSpec.SeriesNames = obj.Variables;
            
            try
                % Estimate the VAR parameters
                obj.EstimatedModel = estimate(obj.ModelSpec, Y);
                obj.FEVD = fevd(obj.EstimatedModel); % Precompute FEVD once
                Logger.success('VAR Model estimated successfully.');
            catch ME
                Logger.warning('VAR estimation failed: %s. Using default specification.', ME.message);
                rethrow(ME);
            end
        end
        
        function [forecastY, fevdResult] = forecastAndDecompose(obj, numPeriods, dataTable)
            % Forecasts future price changes and sentiment, and returns precomputed FEVD
            if isempty(obj.EstimatedModel)
                error('VARModel:ModelNotEstimated', 'Model must be estimated before forecasting.');
            end
            
            % Extract last observed data as presample
            prices = dataTable.Close;
            priceChange = [0; diff(prices)];
            sentiment = dataTable.Daily_Sentiment;
            Y = [priceChange, sentiment];
            
            presample = Y(end-obj.NumLags+1:end, :);
            
            % Generate forecast
            forecastY = forecast(obj.EstimatedModel, numPeriods, presample);
            fevdResult = obj.FEVD;
        end
    end
end
