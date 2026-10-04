classdef ModelManager
    % ModelManager Handles saving and loading trained models, scalers, and 
    % feature metadata in the models/ directory for production use.
    
    properties
        ModelDir
    end
    
    methods
        function obj = ModelManager()
            % Setup model directory
            obj.ModelDir = fullfile(pwd, 'models');
            if ~exist(obj.ModelDir, 'dir')
                mkdir(obj.ModelDir);
            end
        end
        
        %% Save Model & Metadata (Training Mode)
        function saveArtifacts(obj, cnnModel, lstmModel, arimaModel, ensembleWeights, scaler, targetScaler, featureList, varargin)
            Logger.info('Saving trained artifacts to models/ directory...');
            
            % Save MATLAB artifacts (.mat)
            save(fullfile(obj.ModelDir, 'cnn_lstm.mat'), 'cnnModel', 'lstmModel');
            save(fullfile(obj.ModelDir, 'arima.mat'), 'arimaModel');
            save(fullfile(obj.ModelDir, 'ensemble.mat'), 'ensembleWeights');
            save(fullfile(obj.ModelDir, 'scaler.mat'), 'scaler');
            save(fullfile(obj.ModelDir, 'targetScaler.mat'), 'targetScaler');
            save(fullfile(obj.ModelDir, 'feature_list.mat'), 'featureList');
            
            % Optional metadata kwargs
            p = inputParser;
            addParameter(p, 'sequenceLength', 30);
            addParameter(p, 'modelType', '');
            addParameter(p, 'arimaModelType', '');
            addParameter(p, 'fallbackReason', '');
            addParameter(p, 'dataset', '');
            parse(p, varargin{:});

            % Get Git Commit Hash dynamically (fails gracefully if not git repo)
            [gitStatus, gitHash] = system('git rev-parse HEAD 2>nul');
            if gitStatus ~= 0, gitHash = 'unknown'; end
            
            % Generate and save model_info.json
            info = struct();
            info.trained_on = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
            info.git_commit = strtrim(gitHash);
            info.matlab_version = version;

            if ~isempty(p.Results.dataset)
                info.dataset = p.Results.dataset;
            else
                info.dataset = 'BTC_Daily_1d (btc.csv)';
            end
            info.features = length(featureList);
            info.sequence_length = double(p.Results.sequenceLength);
            info.version = 'v1.0.0';
            if ~isempty(p.Results.modelType)
                info.model_type = char(p.Results.modelType);
            end
            if ~isempty(p.Results.arimaModelType)
                info.arima_model_type = char(p.Results.arimaModelType);
            end
            % Always emit fallback_reason (empty string when no fallback) so metadata is machine-verifiable
            info.fallback_reason = char(p.Results.fallbackReason);
            
            jsonStr = jsonencode(info, 'PrettyPrint', true);
            fid = fopen(fullfile(obj.ModelDir, 'model_info.json'), 'w');
            if fid ~= -1
                fprintf(fid, '%s', jsonStr);
                fclose(fid);
                Logger.success('Artifacts and model_info.json saved successfully.');
            else
                Logger.warning('Failed to write model_info.json');
            end
        end
        
        %% Load Artifacts (Prediction Mode)
        function [models, scaler, featureList, targetScaler] = loadArtifacts(obj)
            Logger.info('Loading models from models/ (Fast Load < 100ms)...');
            models = struct();
            
            try
                % Load networks
                cnn_lstm = load(fullfile(obj.ModelDir, 'cnn_lstm.mat'));
                models.CNN = cnn_lstm.cnnModel;
                models.LSTM = cnn_lstm.lstmModel;
                
                arima = load(fullfile(obj.ModelDir, 'arima.mat'));
                models.ARIMA = arima.arimaModel;
                
                ens = load(fullfile(obj.ModelDir, 'ensemble.mat'));
                models.EnsembleWeights = ens.ensembleWeights;
                
                % Load scalers and metadata
                sc = load(fullfile(obj.ModelDir, 'scaler.mat'));
                scaler = sc.scaler;
                
                % Load target scaler if exists (for backwards compat)
                targetScaler = [];
                if exist(fullfile(obj.ModelDir, 'targetScaler.mat'), 'file')
                    ts = load(fullfile(obj.ModelDir, 'targetScaler.mat'));
                    targetScaler = ts.targetScaler;
                end
                
                feat = load(fullfile(obj.ModelDir, 'feature_list.mat'));
                featureList = feat.featureList;
                
                % Read JSON for logging version
                fid = fopen(fullfile(obj.ModelDir, 'model_info.json'), 'r');
                if fid ~= -1
                    raw = fread(fid, '*char')';
                    fclose(fid);
                    info = jsondecode(raw);
                    Logger.info('Loaded Model Version: %s (Trained on: %s)', info.version, info.trained_on);
                end
                
            catch ME
                Logger.error('Failed to load artifacts. Has train_pipeline.m been run? Error: %s', ME.message);
                error('ModelManager:LoadFailed', 'Could not load required .mat files.');
            end
        end
    end
end
