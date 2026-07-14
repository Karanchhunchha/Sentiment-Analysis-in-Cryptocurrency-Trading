classdef RiskEngine < handle
    % RiskEngine Computes Stop Loss (SL) and Take Profit (TP) bounds using 
    % Average True Range (ATR) and strictly enforces Risk:Reward > 1.5
    
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
