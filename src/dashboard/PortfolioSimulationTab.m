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
                % Need price data and predictions.
                % Simulation is heavy if I run the full pipeline. 
                % I will use historical performance as a shortcut or prepare minimal data.
                
                priceData = PriceDataLoader('BTCUSDT', '1h').fetchRecentHistory(200);
                [~, X, Y] = PipelineDataProcessor.prepareData();
                mgr = ModelManager();
                [models, scaler, featureList, targetScaler] = mgr.loadArtifacts();
                preds = PipelineDataProcessor.predictEnsemble(models, X, targetScaler, scaler, featureList);
                
                sim = PortfolioSimulator(10000);
                % Align predictions to priceData rows
                metrics = sim.runSimulation(priceData, preds, 'prod_v1', 'SentinelCrypto');
                
                res = sprintf('Simulation Complete.\nTotal Return: %.2f%%\nSharpe: %.2f\nMax Drawdown: %.2f%%\nFinal BTC Weight: %.2f', ...
                    metrics.TotalReturn * 100, metrics.SharpeRatio, metrics.MaxDrawdown * 100, metrics.FinalBTCWeight);
                obj.TextArea.Value = res;
                obj.AppRef.updateStatus('Simulation Complete.', [0 0.5 0]);
            catch e
                obj.AppRef.updateStatus(['Error: ' e.message], [0.8 0 0]);
                obj.TextArea.Value = e.message;
            end
        end
    end
end
