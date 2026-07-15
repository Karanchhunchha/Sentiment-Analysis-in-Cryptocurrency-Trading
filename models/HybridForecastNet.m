%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto

classdef HybridForecastNet < handle
    % HYBRIDFORECASTNET Deep learning architecture for price forecasting
    % Fuses time-series market data (Price, Volume, Tech Indicators) with
    % Sentiment scores using a CNN-LSTM hybrid architecture.
    
    properties
        Layers
        NetworkOptions
        TrainedNet
        IsTrained = false
    end
    
    methods
        function obj = HybridForecastNet(numFeatures, sequenceLength)
            % Defines the CNN-LSTM architecture
            % CNN extracts spatial features (relationships between sentiment, RSI, volume, etc.)
            % LSTM processes the temporal sequence of these extracted features
            
            if nargin < 2
                sequenceLength = 30; % Default 30 time steps
            end
            if nargin < 1
                numFeatures = 8; % e.g., Close, Vol, RSI, MACD, Vader, Ratio, Finbert, Fused
            end
            
            % Build the Deep Learning Toolbox Layer Graph
            obj.Layers = [ ...
                sequenceInputLayer(numFeatures, 'Name', 'input')
                
                % 1D Convolution for spatial feature extraction across channels
                convolution1dLayer(3, 32, 'Padding', 'same', 'Name', 'conv1')
                batchNormalizationLayer('Name', 'bn1')
                reluLayer('Name', 'relu1')
                
                % Long Short-Term Memory for temporal dependencies
                lstmLayer(64, 'OutputMode', 'last', 'Name', 'lstm1')
                dropoutLayer(0.2, 'Name', 'drop1')
                
                % Fully Connected layers to regression output
                fullyConnectedLayer(32, 'Name', 'fc1')
                reluLayer('Name', 'relu2')
                fullyConnectedLayer(1, 'Name', 'output')
                regressionLayer('Name', 'regressionoutput')];
            
            % Define training options
            obj.NetworkOptions = trainingOptions('adam', ...
                'MaxEpochs', 50, ...
                'MiniBatchSize', 32, ...
                'InitialLearnRate', 0.001, ...
                'LearnRateSchedule', 'piecewise', ...
                'LearnRateDropPeriod', 20, ...
                'LearnRateDropFactor', 0.5, ...
                'Shuffle', 'every-epoch', ...
                'Verbose', false, ...
                'Plots', 'none'); % Turn on 'training-progress' for UI
        end
        
        function train(obj, XTrain, YTrain, XValidation, YValidation)
            % Trains the network using MATLAB trainNetwork
            if nargin == 5 && ~isempty(XValidation)
                obj.NetworkOptions.ValidationData = {XValidation, YValidation};
                obj.NetworkOptions.ValidationFrequency = 10;
            end
            
            disp('⏳ Training Hybrid CNN-LSTM Network...');
            try
                obj.TrainedNet = trainNetwork(XTrain, YTrain, obj.Layers, obj.NetworkOptions);
                obj.IsTrained = true;
                disp('✅ Network training completed successfully.');
            catch ME
                disp('❌ Error during network training:');
                disp(ME.message);
                obj.IsTrained = false;
            end
        end
        
        function YPred = predict(obj, XTest)
            % Generates predictions
            if ~obj.IsTrained
                error('Network is not trained yet.');
            end
            
            disp('🧠 Generating predictions from CNN-LSTM...');
            YPred = predict(obj.TrainedNet, XTest);
        end
    end
end
