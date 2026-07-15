classdef FeatureEngineer
    % FeatureEngineer Automatically calculates technical indicators and market structure metrics
    
    methods (Static)
        function df = runAll(df)
            % Ensure we have OHLCV data
            if isempty(df) || height(df) == 0
                error('Dataframe is empty.');
            end
            
            Logger.info('Starting Feature Engineering pipeline...');
            
            df = FeatureEngineer.calcMovingAverages(df);
            df = FeatureEngineer.calcMomentum(df);
            df = FeatureEngineer.calcVolatility(df);
            df = FeatureEngineer.calcReturns(df);
            df = FeatureEngineer.calcMarketStructure(df);
            df = FeatureEngineer.calcOrderBlocks(df);
            df = FeatureEngineer.calcLiquidityZones(df);
            
            Logger.success('Feature Engineering complete. Added %d new features.', size(df,2)-5);
        end
        
        function df = calcMovingAverages(df)
            % Simple Moving Averages
            df.SMA_20 = movmean(df.Close, 20);
            df.SMA_50 = movmean(df.Close, 50);
            df.SMA_200 = movmean(df.Close, 200);
            
            % Exponential Moving Averages
            alpha12 = 2 / (12 + 1);
            alpha26 = 2 / (26 + 1);
            
            % Pre-allocate
            df.EMA_12 = zeros(height(df), 1);
            df.EMA_26 = zeros(height(df), 1);
            
            df.EMA_12(1) = df.Close(1);
            df.EMA_26(1) = df.Close(1);
            
            for i = 2:height(df)
                df.EMA_12(i) = df.Close(i) * alpha12 + df.EMA_12(i-1) * (1 - alpha12);
                df.EMA_26(i) = df.Close(i) * alpha26 + df.EMA_26(i-1) * (1 - alpha26);
            end
            
            % VWAP (Volume Weighted Average Price) approximation over a rolling 24-period window
            typicalPrice = (df.High + df.Low + df.Close) / 3;
            volXPrice = typicalPrice .* df.Volume;
            df.VWAP = movsum(volXPrice, 24) ./ movsum(df.Volume, 24);
        end
        
        function df = calcMomentum(df)
            % RSI
            priceDiff = [0; diff(df.Close)];
            gains = max(priceDiff, 0);
            losses = -min(priceDiff, 0);
            
            avgGain = movmean(gains, 14);
            avgLoss = movmean(losses, 14);
            
            % Avoid divide by zero
            rs = avgGain ./ max(avgLoss, 1e-10);
            df.RSI = 100 - (100 ./ (1 + rs));
            
            % MACD
            df.MACD_Line = df.EMA_12 - df.EMA_26;
            
            % MACD Signal (9-period EMA of MACD Line)
            alpha9 = 2 / (9 + 1);
            df.MACD_Signal = zeros(height(df), 1);
            df.MACD_Signal(1) = df.MACD_Line(1);
            for i = 2:height(df)
                df.MACD_Signal(i) = df.MACD_Line(i) * alpha9 + df.MACD_Signal(i-1) * (1 - alpha9);
            end
            
            df.MACD_Hist = df.MACD_Line - df.MACD_Signal;
            
            % Simple Momentum (10-period)
            df.Momentum = [zeros(10,1); df.Close(11:end) - df.Close(1:end-10)];
        end
        
        function df = calcVolatility(df)
            % True Range and ATR
            tr1 = df.High - df.Low;
            tr2 = abs(df.High - [0; df.Close(1:end-1)]);
            tr3 = abs(df.Low - [0; df.Close(1:end-1)]);
            
            trueRange = max([tr1, tr2, tr3], [], 2);
            df.ATR = movmean(trueRange, 14);
            
            % Bollinger Bands
            stdDev = movstd(df.Close, 20);
            df.BB_Upper = df.SMA_20 + (2 * stdDev);
            df.BB_Lower = df.SMA_20 - (2 * stdDev);
            df.BB_Width = (df.BB_Upper - df.BB_Lower) ./ df.SMA_20;
            
            % Rolling Volatility (20-period standard deviation of returns)
            returns = [0; diff(df.Close) ./ df.Close(1:end-1)];
            df.Rolling_Vol = movstd(returns, 20);
        end
        
        function df = calcReturns(df)
            % Simple Returns
            df.Returns = [0; diff(df.Close) ./ df.Close(1:end-1)];
            
            % Log Returns
            df.Log_Returns = [0; diff(log(df.Close))];
            
            % Volume Features (Rate of Change)
            df.Volume_ROC = [0; diff(df.Volume) ./ max(df.Volume(1:end-1), 1e-10)];
        end
        
        function df = calcMarketStructure(df)
            % Basic Trend Strength (Distance from 200 SMA)
            df.Trend_Strength = (df.Close - df.SMA_200) ./ df.SMA_200;
            
            % Market Regime (1 = Bullish, -1 = Bearish, 0 = Ranging)
            df.Market_Regime = zeros(height(df), 1);
            df.Market_Regime(df.Close > df.SMA_50 & df.SMA_50 > df.SMA_200) = 1;
            df.Market_Regime(df.Close < df.SMA_50 & df.SMA_50 < df.SMA_200) = -1;
            
            % Local Support/Resistance (Rolling Min/Max over 20 periods)
            df.Support = movmin(df.Low, 20);
            df.Resistance = movmax(df.High, 20);
            
            % Advanced Swing Support/Resistance
            df.Swing_High = df.Resistance;
            df.Swing_Low = df.Support;
        end
        
        function df = calcOrderBlocks(df)
            df.Bullish_OB = zeros(height(df), 1);
            df.Bearish_OB = zeros(height(df), 1);
            
            % Order Block Detection: displacement candle > 1.5x ATR
            for i = 3:height(df)
                body = abs(df.Close(i) - df.Open(i));
                if body > 1.5 * df.ATR(i) && df.Close(i) > df.Open(i) && df.Close(i-1) < df.Open(i-1)
                    df.Bullish_OB(i) = df.Low(i-1);
                elseif body > 1.5 * df.ATR(i) && df.Close(i) < df.Open(i) && df.Close(i-1) > df.Open(i-1)
                    df.Bearish_OB(i) = df.High(i-1);
                end
            end
            
            % Carry forward the last valid Order Block
            for i = 2:height(df)
                if df.Bullish_OB(i) == 0
                    df.Bullish_OB(i) = df.Bullish_OB(i-1);
                end
                if df.Bearish_OB(i) == 0
                    df.Bearish_OB(i) = df.Bearish_OB(i-1);
                end
            end
        end
        
        function df = calcLiquidityZones(df)
            df.Buy_Liquidity = zeros(height(df), 1);
            df.Sell_Liquidity = zeros(height(df), 1);
            
            % Identifying liquidity above recent significant highs and below recent significant lows
            df.Buy_Liquidity = movmax(df.High, 50); % Macro swing high (liquidity pool)
            df.Sell_Liquidity = movmin(df.Low, 50); % Macro swing low (liquidity pool)
        end
    end
end
