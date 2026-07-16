classdef VisualizationConfig
    % VisualizationConfig holds settings for the UI dashboard
    
    properties (Constant)
        % Feature toggles
        ShowSMA = true;
        ShowEMA = true;
        ShowVWAP = true;
        ShowVolume = true;
        ShowIndicators = true; % RSI & MACD
        
        % SMC and Institutional
        ShowSupportResistance = true;
        ShowLiquidity = true;
        ShowOrderBlocks = true;
        ShowOrderBook = true;
        
        % Prediction & Forecasting
        ForecastHorizons = struct('Steps', [1, 3, 5, 10, 20], 'Timeframe', '15m');
        ShowConfidenceBand = true;
        ShowActualVsPrediction = true;
        ShowPredictionMarkers = true;
        PredictionColor = [0.2 0.6 1.0]; % Light Blue
        
        % Forecast Formatting
        ProjectedLineStyle = ':';
        ModelLineStyle = '--';      
        % Rendering
        MaxHistoryLength = 200; % Maximum number of candles to render on chart
    end
end
