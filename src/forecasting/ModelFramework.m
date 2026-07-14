classdef ModelFramework
    % ModelFramework Handles model lifecycle, training, validation, and versioning
    
    properties (Constant)
        ModelsDir = fullfile(pwd, 'data', 'models');
    end
    
    methods (Static)
        function init()
            if ~exist(ModelFramework.ModelsDir, 'dir')
                mkdir(ModelFramework.ModelsDir);
            end
        end
        
        function versionId = generateVersionId(modelType)
            % e.g. CNNLSTM_20260714_120000
            timeStr = datestr(now, 'yyyymmdd_HHMMSS');
            versionId = sprintf('%s_%s', upper(modelType), timeStr);
        end
        
        function saveModel(model, modelType, datasetVersion, metrics, hyperparams)
            ModelFramework.init();
            
            versionId = ModelFramework.generateVersionId(modelType);
            filePath = fullfile(ModelFramework.ModelsDir, [versionId '.mat']);
            
            % Save to disk
            save(filePath, 'model', 'metrics', 'hyperparams', 'datasetVersion');
            Logger.success('Saved new model version: %s', versionId);
            
            % Track in PostgreSQL
            conn = DataIngestion.getDbConnection();
            if ~isempty(conn) && isopen(conn)
                try
                    hpJson = jsonencode(hyperparams);
                    query = sprintf(...
                        "INSERT INTO models (model_id, version, algorithm, dataset_version, rmse, directional_accuracy, hyperparameters) " + ...
                        "VALUES ('%s', 1, '%s', '%s', %f, %f, '%s');", ...
                        versionId, modelType, datasetVersion, metrics.rmse, metrics.directional_accuracy, hpJson);
                    execute(conn, query);
                catch e
                    Logger.error('Failed to log model to database: %s', e.message);
                end
                close(conn);
            end
        end
        
        function logExperiment(modelId, featuresUsed, params, valRmse, valMae, notes)
            conn = DataIngestion.getDbConnection();
            if ~isempty(conn) && isopen(conn)
                try
                    featJson = jsonencode(featuresUsed);
                    paramJson = jsonencode(params);
                    
                    query = sprintf(...
                        "INSERT INTO experiments (model_id, features_used, parameters, val_rmse, val_mae, notes) " + ...
                        "VALUES ('%s', '%s', '%s', %f, %f, '%s');", ...
                        modelId, featJson, paramJson, valRmse, valMae, notes);
                    execute(conn, query);
                catch e
                    Logger.error('Failed to log experiment: %s', e.message);
                end
                close(conn);
            end
        end
        
        function [model, fallbackPath] = loadBestModel(modelType)
            % Failover Model Loading
            % If the requested model type fails to load, it attempts fallbacks
            fallbacks = {'CNNLSTM', 'LSTM', 'ARIMAX', 'ARIMA'};
            
            startIdx = find(strcmp(fallbacks, upper(modelType)));
            if isempty(startIdx)
                startIdx = 1;
            end
            
            model = [];
            fallbackPath = '';
            
            for i = startIdx:length(fallbacks)
                currentType = fallbacks{i};
                Logger.info('Attempting to load %s...', currentType);
                
                % Query DB for best model of this type
                conn = DataIngestion.getDbConnection();
                if ~isempty(conn) && isopen(conn)
                    query = sprintf("SELECT model_id FROM models WHERE algorithm = '%s' AND status = 'ACTIVE' ORDER BY rmse ASC LIMIT 1", currentType);
                    try
                        res = select(conn, query);
                        if height(res) > 0
                            bestId = res.model_id{1};
                            filePath = fullfile(ModelFramework.ModelsDir, [bestId '.mat']);
                            if exist(filePath, 'file')
                                loaded = load(filePath);
                                model = loaded.model;
                                fallbackPath = currentType;
                                Logger.success('Successfully loaded %s', bestId);
                                close(conn);
                                return;
                            end
                        end
                    catch
                    end
                    close(conn);
                end
                Logger.warn('%s unavailable. Trying fallback...', currentType);
            end
            
            Logger.error('All model failovers exhausted.');
        end
    end
end
