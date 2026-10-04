classdef FeatureFusionEngine < handle
    % FeatureFusionEngine Handles real-time fusion of market data, indicators,
    % and sentiment. Optimizes for < 50ms latency by calculating incrementally.
    
    properties
        FeatureCache
        LastClose
        LastEMA
        LastAvgGain
        LastAvgLoss
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
            n = height(fusedData);
            
            fusedData.EMA_20 = zeros(n, 1);
            fusedData.RSI = zeros(n, 1);
            
            if n > 0
                % Initialize EMA_20
                fusedData.EMA_20(1) = fusedData.Close(1);
                alpha = 2 / (20 + 1);
                for i = 2:n
                    fusedData.EMA_20(i) = (fusedData.Close(i) * alpha) + (fusedData.EMA_20(i-1) * (1 - alpha));
                end
                
                % Initialize RSI (14 period, Wilder's smoothing)
                period = 14;
                diffs = [0; diff(fusedData.Close)];
                gains = max(0, diffs);
                losses = max(0, -diffs);
                
                avgGain = zeros(n, 1);
                avgLoss = zeros(n, 1);
                
                if n > period
                    avgGain(period+1) = mean(gains(2:period+1));
                    avgLoss(period+1) = mean(losses(2:period+1));
                    
                    for i = period+2:n
                        avgGain(i) = (avgGain(i-1) * (period - 1) + gains(i)) / period;
                        avgLoss(i) = (avgLoss(i-1) * (period - 1) + losses(i)) / period;
                    end
                end
                
                rs = avgGain ./ max(avgLoss, 1e-8);
                fusedData.RSI = 100 - (100 ./ (1 + rs));
                fusedData.RSI(1:period) = 50; % Default before enough data
                
                % Store internal state for rapid incremental updates
                obj.LastClose = fusedData.Close(end);
                obj.LastEMA = fusedData.EMA_20(end);
                obj.LastAvgGain = avgGain(end);
                obj.LastAvgLoss = avgLoss(end);
            end
            
            if n > 0
                currentState = fusedData(end, :);
            else
                currentState = table();
            end
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
            
            % 2. Incremental RSI Update (Wilder's smoothing)
            if isempty(obj.LastClose)
                obj.LastClose = currentPrice;
            end
            
            period = 14;
            diffPrice = currentPrice - obj.LastClose;
            gain = max(0, diffPrice);
            loss = max(0, -diffPrice);
            
            if isempty(obj.LastAvgGain) || isempty(obj.LastAvgLoss)
                obj.LastAvgGain = gain;
                obj.LastAvgLoss = loss;
            end
            
            newAvgGain = (obj.LastAvgGain * (period - 1) + gain) / period;
            newAvgLoss = (obj.LastAvgLoss * (period - 1) + loss) / period;
            
            rs = newAvgGain / max(newAvgLoss, 1e-8);
            newRSI = 100 - (100 / (1 + rs));
            
            % Update Internal State
            obj.LastClose = currentPrice;
            obj.LastEMA = newEMA;
            obj.LastAvgGain = newAvgGain;
            obj.LastAvgLoss = newAvgLoss;
            
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
