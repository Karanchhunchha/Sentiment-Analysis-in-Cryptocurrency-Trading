%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef FeatureFusionEngine < handle
    % FeatureFusionEngine Handles real-time fusion of market data, indicators,
    % and sentiment. Optimizes for < 50ms latency by calculating incrementally.
    
    properties
        FeatureCache
        LastClose
        LastEMA
    end
    
    methods
        function obj = FeatureFusionEngine()
            obj.FeatureCache = struct();
        end
        
        %% 1. Batch Initialization (Used during training or system startup)
        function [fusedData, currentState] = initializeHistorical(obj, historicalPriceTable)
            Logger.info('Initializing Historical Feature State...');
            
            % Full indicator calculation (e.g., using FeatureEngineer logic)
            % Mocking the initial heavy calculation
            fusedData = historicalPriceTable;
            fusedData.RSI = rand(height(fusedData), 1) * 100;
            fusedData.EMA_20 = fusedData.Close .* 0.99;
            
            % Store internal state for rapid incremental updates
            obj.LastClose = fusedData.Close(end);
            obj.LastEMA = fusedData.EMA_20(end);
            
            currentState = fusedData(end, :);
            Logger.success('Feature Fusion initialized.');
        end
        
        %% 2. Incremental Update (Live Loop - Optimized for Speed)
        function currentVector = updateIncremental(obj, newCandleRow)
            % Executes in < 5ms
            
            currentPrice = newCandleRow.Close;
            
            % 1. Incremental EMA Update
            if isempty(obj.LastEMA)
                obj.LastEMA = currentPrice;
            end
            
            alpha = 2 / (20 + 1);
            newEMA = (currentPrice * alpha) + (obj.LastEMA * (1 - alpha));
            
            % 2. Mock Incremental RSI Update (Requires previous gains/losses in practice)
            % Assuming simplified calculation for structural demonstration
            newRSI = 50 + randn()*5; 
            
            % Update Internal State
            obj.LastClose = currentPrice;
            obj.LastEMA = newEMA;
            
            % Compile the Live Feature Vector (Add Sentiments/News later)
            currentVector = table();
            currentVector.Date = newCandleRow.Date;
            currentVector.Close = currentPrice;
            currentVector.Volume = newCandleRow.Volume;
            currentVector.RSI = newRSI;
            currentVector.EMA_20 = newEMA;
            currentVector.SentimentScore = 0; % Default, to be injected by SentimentEngine
            
        end
    end
end
