%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto

classdef MarketSequenceBuilder < handle
    % MARKETSEQUENCEBUILDER Implements rolling-origin walk-forward validation
    % Ensures robust out-of-sample data generation without lookahead bias.
    
    properties
        SequenceLength = 30; % Lookback period
        PredictionHorizon = 1; % Steps ahead to predict
    end
    
    methods
        function obj = MarketSequenceBuilder(seqLen, horizon)
            if nargin > 0
                obj.SequenceLength = seqLen;
                obj.PredictionHorizon = horizon;
            end
        end
        
        function [X, Y] = buildWalkForwardSequences(obj, rawData)
            % Converts tabular data into 3D arrays (Features x Sequence x Batch)
            % Applies strict per-window Z-score normalization.
            disp('================================================');
            disp('   🏗️ Building Walk-Forward Sequences... ');
            disp('================================================');
            
            % Convert table to numeric array for faster processing
            if istable(rawData)
                dataMatrix = table2array(rawData);
            else
                dataMatrix = rawData;
            end
            
            numSamples = size(dataMatrix, 1);
            numFeatures = size(dataMatrix, 2);
            
            validWindows = numSamples - obj.SequenceLength - obj.PredictionHorizon + 1;
            
            % Initialize containers
            X = zeros(numFeatures, obj.SequenceLength, validWindows);
            Y = zeros(1, validWindows); % Target is typically future 'Close' price
            
            closeColIndex = 4; % Assuming OHLCV order: Close is 4th col
            
            for i = 1:validWindows
                % Extract the window
                windowData = dataMatrix(i:(i + obj.SequenceLength - 1), :);
                
                % Per-window Z-score normalization (crucial for preventing data leakage)
                windowMean = mean(windowData, 1);
                windowStd = std(windowData, 0, 1);
                windowStd(windowStd == 0) = 1; % Prevent div by zero
                
                normWindow = (windowData - windowMean) ./ windowStd;
                
                % Store transposed for CNN/LSTM (Features x SeqLength)
                X(:, :, i) = normWindow';
                
                % Extract target (future close price, normalized relative to the current window)
                futurePrice = dataMatrix(i + obj.SequenceLength + obj.PredictionHorizon - 1, closeColIndex);
                % Normalize target using the SAME stats as the window (to keep scaling consistent)
                normFuture = (futurePrice - windowMean(closeColIndex)) / windowStd(closeColIndex);
                
                Y(i) = normFuture;
            end
            
            disp(['✅ Built ' num2str(validWindows) ' overlapping sequences.']);
            disp(['📊 Window Size: ' num2str(obj.SequenceLength) ', Step: 1, Horizon: ' num2str(obj.PredictionHorizon)]);
        end
    end
end
