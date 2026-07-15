%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
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
        function saveArtifacts(obj, cnnModel, lstmModel, arimaModel, ensembleWeights, scaler, targetScaler, featureList)
            Logger.info('Saving trained artifacts to models/ directory...');
            
            % Save MATLAB artifacts (.mat)
            save(fullfile(obj.ModelDir, 'cnn_lstm.mat'), 'cnnModel', 'lstmModel');
            save(fullfile(obj.ModelDir, 'arima.mat'), 'arimaModel');
            save(fullfile(obj.ModelDir, 'ensemble.mat'), 'ensembleWeights');
            save(fullfile(obj.ModelDir, 'scaler.mat'), 'scaler');
            save(fullfile(obj.ModelDir, 'targetScaler.mat'), 'targetScaler');
            save(fullfile(obj.ModelDir, 'feature_list.mat'), 'featureList');
            
            % Get Git Commit Hash dynamically (fails gracefully if not git repo)
            [gitStatus, gitHash] = system('git rev-parse --short HEAD');
            if gitStatus ~= 0, gitHash = 'unknown'; end
            
            % Generate and save model_info.json
            info = struct();
            info.trained_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            info.dataset = 'BTC_Historical_15m (v2.4.1)';
            info.features = length(featureList);
            info.version = 'v1.0.0';
            info.git_commit = strtrim(gitHash);
            info.matlab_version = version;
            
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
