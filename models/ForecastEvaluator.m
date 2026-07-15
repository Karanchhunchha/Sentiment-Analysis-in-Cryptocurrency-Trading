%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto

classdef ForecastEvaluator < handle
    % FORECASTEVALUATOR Transforms model outputs into explainable research signals
    % Provides actionable, evidence-based outputs (BUY/SELL/HOLD) based on
    % a fusion of forecast, sentiment, and liquidity.
    
    methods
        function obj = ForecastEvaluator()
        end
        
        function report = generateSignal(obj, currentPrice, predictedPrice, sentimentScore, rsi, liquidityStatus)
            % Generates an explainable research signal
            
            % Calculate expected return
            expectedReturn = (predictedPrice - currentPrice) / currentPrice;
            
            % Heuristic thresholds
            isBullishForecast = expectedReturn > 0.01; % Expect > 1% gain
            isBearishForecast = expectedReturn < -0.01; % Expect > 1% loss
            
            isBullishSentiment = sentimentScore > 0.3;
            isBearishSentiment = sentimentScore < -0.3;
            
            % Determine Signal
            signal = 'HOLD';
            confidence = 50; % Base confidence
            factors = {};
            
            if isBullishForecast && isBullishSentiment
                signal = 'BUY';
                confidence = 80;
                factors{end+1} = 'Positive multi-modal sentiment detected.';
                factors{end+1} = sprintf('CNN-LSTM forecasts a +%.2f%% move.', expectedReturn * 100);
            elseif isBearishForecast && isBearishSentiment
                signal = 'SELL';
                confidence = 80;
                factors{end+1} = 'Negative multi-modal sentiment detected.';
                factors{end+1} = sprintf('CNN-LSTM forecasts a %.2f%% drop.', expectedReturn * 100);
            elseif isBullishForecast && isBearishSentiment
                factors{end+1} = 'Conflicting signals: Models predict gain, but sentiment is negative.';
                confidence = 40;
            elseif isBearishForecast && isBullishSentiment
                factors{end+1} = 'Conflicting signals: Models predict drop, but sentiment is positive.';
                confidence = 40;
            end
            
            % Adjust for RSI (Overbought/Oversold)
            if rsi > 70
                if strcmp(signal, 'BUY')
                    signal = 'HOLD';
                    factors{end+1} = 'Warning: Asset is overbought (RSI > 70). Downgrading to HOLD.';
                    confidence = confidence - 20;
                else
                    factors{end+1} = 'Asset is overbought (RSI > 70).';
                end
            elseif rsi < 30
                if strcmp(signal, 'SELL')
                    signal = 'HOLD';
                    factors{end+1} = 'Warning: Asset is oversold (RSI < 30). Downgrading to HOLD.';
                    confidence = confidence - 20;
                else
                    factors{end+1} = 'Asset is oversold (RSI < 30).';
                end
            end
            
            % Adjust for Liquidity
            if strcmp(liquidityStatus, 'Low')
                confidence = confidence - 15;
                factors{end+1} = 'Low trading volume/liquidity detected. Risk of slippage.';
            else
                factors{end+1} = 'Healthy liquidity supports signal execution.';
            end
            
            % Format the report
            report = sprintf('\n=======================================\n');
            report = [report sprintf('       MARKET ASSESSMENT REPORT        \n')];
            report = [report sprintf('=======================================\n\n')];
            report = [report sprintf('Asset:          BTC\n')];
            report = [report sprintf('Current Price:  $%.2f\n', currentPrice)];
            report = [report sprintf('Predicted:      $%.2f\n', predictedPrice)];
            
            % Sentiment text
            if sentimentScore > 0
                sentText = 'Bullish';
            elseif sentimentScore < 0
                sentText = 'Bearish';
            else
                sentText = 'Neutral';
            end
            report = [report sprintf('Sentiment:      %s (%.2f)\n', sentText, sentimentScore)];
            report = [report sprintf('Liquidity:      %s\n', liquidityStatus)];
            report = [report sprintf('RSI:            %.1f\n\n', rsi)];
            
            report = [report sprintf('SUGGESTED RESEARCH SIGNAL: ** %s **\n', signal)];
            report = [report sprintf('CONFIDENCE:                %d%%\n\n', round(confidence))];
            
            report = [report sprintf('Supporting Factors:\n')];
            for i = 1:length(factors)
                report = [report sprintf(' • %s\n', factors{i})];
            end
            report = [report sprintf('=======================================\n')];
        end
    end
end
