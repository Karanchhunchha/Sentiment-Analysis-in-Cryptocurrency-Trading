classdef IndicatorEngine
    % IndicatorEngine Computes robust technical indicators on historical data.
    % Avoids reliance on specific Financial Toolbox functions to ensure 
    % maximum compatibility.
    
    methods (Static)
        function data = calculateAll(data)
            Logger.info('Calculating Technical Indicators...');
            
            closeP = data.Close;
            highP = data.High;
            lowP = data.Low;
            vol = data.Volume;
            
            % SMA & EMA
            data.SMA_20 = movmean(closeP, 20);
            data.SMA_50 = movmean(closeP, 50);
            data.EMA_20 = IndicatorEngine.calcEMA(closeP, 20);
            data.EMA_50 = IndicatorEngine.calcEMA(closeP, 50);
            
            % MACD
            ema12 = IndicatorEngine.calcEMA(closeP, 12);
            ema26 = IndicatorEngine.calcEMA(closeP, 26);
            data.MACD_Line = ema12 - ema26;
            data.MACD_Signal = IndicatorEngine.calcEMA(data.MACD_Line, 9);
            data.MACD_Hist = data.MACD_Line - data.MACD_Signal;
            
            % RSI (14-period)
            data.RSI_14 = IndicatorEngine.calcRSI(closeP, 14);
            
            % Bollinger Bands (20-period, 2-std)
            std20 = movstd(closeP, 20);
            data.BB_Upper = data.SMA_20 + (2 .* std20);
            data.BB_Lower = data.SMA_20 - (2 .* std20);
            
            % VWAP
            typicalPrice = (highP + lowP + closeP) / 3;
            cumVol = cumsum(vol);
            cumVolPrice = cumsum(typicalPrice .* vol);
            data.VWAP = cumVolPrice ./ max(cumVol, 1e-8);
            
            % Volatility (Rolling standard deviation of returns)
            returns = [0; diff(closeP) ./ closeP(1:end-1)];
            data.Volatility_20 = movstd(returns, 20);
            
            % True Range & ATR
            tr = max([highP - lowP, ...
                      abs(highP - [closeP(1); closeP(1:end-1)]), ...
                      abs(lowP - [closeP(1); closeP(1:end-1)])], [], 2);
            data.ATR_14 = IndicatorEngine.calcEMA(tr, 14);
            
            % Drop initial NaN rows due to lookback periods
            data(1:50, :) = [];
            
            Logger.success('Indicators calculated successfully. Added 14 features.');
        end
        
        function ema = calcEMA(dataVector, period)
            % Exponential Moving Average
            alpha = 2 / (period + 1);
            ema = zeros(size(dataVector));
            ema(1) = dataVector(1);
            for i = 2:length(dataVector)
                ema(i) = (dataVector(i) * alpha) + (ema(i-1) * (1 - alpha));
            end
        end
        
        function rsi = calcRSI(dataVector, period)
            % Relative Strength Index
            diffs = [0; diff(dataVector)];
            gains = max(0, diffs);
            losses = max(0, -diffs);
            
            avgGain = movmean(gains, period);
            avgLoss = movmean(losses, period);
            
            rs = avgGain ./ max(avgLoss, 1e-8);
            rsi = 100 - (100 ./ (1 + rs));
        end
    end
end
