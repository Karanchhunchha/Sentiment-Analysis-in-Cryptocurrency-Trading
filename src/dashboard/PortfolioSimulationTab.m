classdef PortfolioSimulationTab < handle
    properties
        Tab, AppRef, TextArea
    end
    
    methods
        function obj = PortfolioSimulationTab(parentGroup, appRef)
            obj.AppRef = appRef;
            obj.Tab = uitab(parentGroup, 'Title', 'Portfolio Simulation');
            obj.buildUI();
        end
        
        function buildUI(obj)
            g = uigridlayout(obj.Tab, [2, 1]);
            g.RowHeight = {40, '1x'};
            uibutton(g, 'Text', 'Run Simulation', 'ButtonPushedFcn', @(b,e) obj.run());
            obj.TextArea = uitextarea(g, 'Editable', 'off', 'FontName', 'FixedWidth');
        end
        
        function run(obj)
            obj.AppRef.updateStatus('Simulating portfolio...');
            try
                % Align interval with model artifacts (15m is the primary trained interval)
                interval = '15m';
                
                [fullData, X, Y] = PipelineDataProcessor.prepareData([], interval);
                mgr = ModelManager(fullfile(pwd, 'models', interval));
                [models, scaler, featureList, targetScaler] = mgr.loadArtifacts();
                
                XScaled = PipelineDataProcessor.scaleData(X, scaler);
                preds = PipelineDataProcessor.predictEnsemble(models, XScaled, targetScaler, scaler, featureList);
                
                % Interval-aware annualization factor for 15m bars: 365 days * 24 hours * 4 quarters = 35,040 periods/year
                annualizationFactor = 365 * 24 * 4;
                slippageRate = 0.0005; % 0.05% slippage
                
                sim = PortfolioSimulator(10000, annualizationFactor, slippageRate);
                
                % Pass explicit price vector and timestamps for validation
                timestamps = fullData.Date;
                metrics = sim.runSimulation(fullData.Close, preds, 'prod_15m', 'SentinelCrypto-Ensemble', timestamps);
                
                res = sprintf('Simulation Complete (%s interval, Annualization: %d periods/yr).\nTotal Return: %.2f%%\nSharpe: %.2f\nMax Drawdown: %.2f%%\nFinal BTC Weight: %.2f', ...
                    interval, annualizationFactor, metrics.TotalReturn * 100, metrics.SharpeRatio, metrics.MaxDrawdown * 100, metrics.FinalBTCWeight);
                obj.TextArea.Value = res;
                obj.AppRef.updateStatus('Simulation Complete.', [0 0.5 0]);
            catch e
                obj.AppRef.updateStatus(['Error: ' e.message], [0.8 0 0]);
                obj.TextArea.Value = e.message;
            end
        end
    end
end
