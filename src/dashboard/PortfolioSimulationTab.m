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
                priceTable = PriceDataLoader('BTCUSDT', interval).fetchRecentHistory(300);
                
                if istable(priceTable)
                    if ismember('Close', priceTable.Properties.VariableNames)
                        priceVec = priceTable.Close;
                    else
                        priceVec = priceTable{:, 5}; % Default kline Close column
                    end
                else
                    priceVec = priceTable;
                end
                
                [fullData, X, Y] = PipelineDataProcessor.prepareData([], interval);
                mgr = ModelManager(fullfile(pwd, 'models', interval));
                [models, scaler, featureList, targetScaler] = mgr.loadArtifacts();
                
                XScaled = PipelineDataProcessor.scaleData(X, scaler);
                preds = PipelineDataProcessor.predictEnsemble(models, XScaled, targetScaler, scaler, featureList);
                
                sim = PortfolioSimulator(10000);
                
                % Ensure exact length alignment with observed close prices
                metrics = sim.runSimulation(fullData.Close, preds, 'prod_15m', 'SentinelCrypto-Ensemble');
                
                res = sprintf('Simulation Complete (%s interval).\nTotal Return: %.2f%%\nSharpe: %.2f\nMax Drawdown: %.2f%%\nFinal BTC Weight: %.2f', ...
                    interval, metrics.TotalReturn * 100, metrics.SharpeRatio, metrics.MaxDrawdown * 100, metrics.FinalBTCWeight);
                obj.TextArea.Value = res;
                obj.AppRef.updateStatus('Simulation Complete.', [0 0.5 0]);
            catch e
                obj.AppRef.updateStatus(['Error: ' e.message], [0.8 0 0]);
                obj.TextArea.Value = e.message;
            end
        end
    end
end
