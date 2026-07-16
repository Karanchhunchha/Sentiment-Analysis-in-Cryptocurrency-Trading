classdef RiskEngine < handle
    % RiskEngine Computes dynamic Risk/Reward, Stop Loss, Take Profit, and ETA
    
    properties
        ATRMultiplierSL
        ATRMultiplierTP
        MinRiskReward
    end
    
    methods
        function obj = RiskEngine(slMult, tpMult, minRR)
            if nargin < 1; slMult = 1.5; end
            if nargin < 2; tpMult = 2.5; end
            if nargin < 3; minRR = 1.5; end
            
            obj.ATRMultiplierSL = slMult;
            obj.ATRMultiplierTP = tpMult;
            obj.MinRiskReward = minRR;
        end
        function [tp, sl, rr, etaMinutes] = calculateRiskMetrics(obj, currentPrice, expectedPath, signal, volatility, support, resistance, metrics, timeframeStr)
            % TP is the peak expected value before confidence decays below threshold
            threshold = metrics.AdaptiveThreshold;
            
            % Currently, confidence metrics are not per-step in this simplified model, 
            % but let's assume we find the local extremum in the path.
            
            if strcmp(signal, 'BUY')
                sl = currentPrice - (volatility + abs(currentPrice - support) * 0.5); 
                risk = currentPrice - sl;
                % Enforce strict Risk:Reward (e.g., 1:3)
                tp = currentPrice + (risk * obj.MinRiskReward);
            elseif strcmp(signal, 'SELL')
                sl = currentPrice + (volatility + abs(currentPrice - resistance) * 0.5);
                risk = sl - currentPrice;
                % Enforce strict Risk:Reward
                tp = currentPrice - (risk * obj.MinRiskReward);
            else
                tp = NaN;
                sl = NaN;
            end
            
            if abs(currentPrice - sl) > 1e-5
                rr = abs(tp - currentPrice) / abs(currentPrice - sl);
            else
                rr = 0;
            end
            
            % Estimate ETA by finding the first index where expectedPath crosses TP
            etaIdx = find(abs(expectedPath - tp) < 1e-5, 1);
            if isempty(etaIdx)
                etaIdx = length(expectedPath);
            end
            
            % Parse timeframe string to minutes (e.g., '15m' -> 15)
            if endsWith(timeframeStr, 'm')
                tfMinutes = str2double(strrep(timeframeStr, 'm', ''));
            elseif endsWith(timeframeStr, 'h')
                tfMinutes = str2double(strrep(timeframeStr, 'h', '')) * 60;
            else
                tfMinutes = 15; % Default
            end
            
            etaMinutes = etaIdx * tfMinutes;
        end
        
        function [validTrade, slPrice, tpPrice] = evaluateTrade(obj, currentPrice, predictedPrice, atrValue)
            % Evaluate if a predicted price movement is worth trading
            
            isLong = predictedPrice > currentPrice;
            isShort = predictedPrice < currentPrice;
            
            % Base distance based on volatility
            slDistance = atrValue * obj.ATRMultiplierSL;
            tpDistance = atrValue * obj.ATRMultiplierTP;
            
            if isLong
                slPrice = currentPrice - slDistance;
                tpPrice = currentPrice + tpDistance;
                % If prediction is lower than TP, TP gets clamped to prediction
                actualTP = min(tpPrice, predictedPrice);
                potentialReward = actualTP - currentPrice;
                potentialRisk = currentPrice - slPrice;
                
            elseif isShort
                slPrice = currentPrice + slDistance;
                tpPrice = currentPrice - tpDistance;
                % If prediction is higher than TP, TP gets clamped
                actualTP = max(tpPrice, predictedPrice);
                potentialReward = currentPrice - actualTP;
                potentialRisk = slPrice - currentPrice;
                
            else
                % No movement predicted
                validTrade = false;
                slPrice = currentPrice;
                tpPrice = currentPrice;
                return;
            end
            
            % Enforce institutional risk constraints
            if potentialRisk <= 0
                validTrade = false;
                return;
            end
            
            rrRatio = potentialReward / potentialRisk;
            validTrade = rrRatio >= obj.MinRiskReward;
        end
    end
end
