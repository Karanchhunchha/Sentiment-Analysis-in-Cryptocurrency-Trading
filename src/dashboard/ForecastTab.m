classdef ForecastTab < handle
    properties
        Tab
        AppRef
        Axes
        PredictionObj
        Visualizer
    end
    
    methods
        function obj = ForecastTab(parentGroup, appRef)
            obj.AppRef = appRef;
            obj.Tab = uitab(parentGroup, 'Title', 'Forecast');
            obj.buildUI();
        end
        
        function buildUI(obj)
            g = uigridlayout(obj.Tab, [2, 1]);
            uibutton(g, 'Text', 'Run Forecast', 'ButtonPushedFcn', @(b,e) obj.runForecast());
            obj.Axes = uiaxes(g);
            obj.Visualizer = PredictionChart(obj.Axes);
        end
        
        function runForecast(obj)
            obj.AppRef.updateStatus('Running Forecast...');
            try
                % Simplified execution
                [fullData, X, ~] = PipelineDataProcessor.prepareData();
                mgr = ModelManager();
                [models, scaler, featureList, targetScaler] = mgr.loadArtifacts();
                preds = PipelineDataProcessor.predictEnsemble(models, X, targetScaler, scaler, featureList);
                
                % Update chart - need to create a predStruct
                predStruct = struct();
                predStruct.Time = fullData.Date;
                predStruct.PredictedPrices = preds;
                obj.Visualizer.update(predStruct);
                
                obj.AppRef.updateStatus('Forecast Complete.', [0 0.5 0]);
            catch e
                obj.AppRef.updateStatus(['Error: ' e.message], [0.8 0 0]);
            end
        end
    end
end
