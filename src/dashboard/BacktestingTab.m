classdef BacktestingTab < handle
    properties
        Tab, AppRef, TextArea
    end
    
    methods
        function obj = BacktestingTab(parentGroup, appRef)
            obj.AppRef = appRef;
            obj.Tab = uitab(parentGroup, 'Title', 'Backtesting');
            obj.buildUI();
        end
        
        function buildUI(obj)
            g = uigridlayout(obj.Tab, [2, 1]);
            g.RowHeight = {40, '1x'};
            uibutton(g, 'Text', 'Run Backtest', 'ButtonPushedFcn', @(b,e) obj.run());
            obj.TextArea = uitextarea(g, 'Editable', 'off', 'FontName', 'FixedWidth');
        end
        
        function run(obj)
            obj.AppRef.updateStatus('Running Backtest...');
            try
                % Backtester is heavy, run with small subset for UI
                histData = PriceDataLoader('BTCUSDT', '1h').fetchRecentHistory(200);
                
                % Must have a model for Backtester.
                mgr = ModelManager();
                [models, ~, ~, ~] = mgr.loadArtifacts();
                riskEngine = RiskEngine();
                
                bt = Backtester(models, riskEngine, histData);
                results = bt.run();
                
                res = sprintf('Backtest Complete.\nFinal Equity: $%.2f\nROI: %.2f%%\nWin Rate: %.2f%%\nMax Drawdown: %.2f%%\nSharpe: %.2f', ...
                    results.FinalEquity, results.ReturnPct * 100, results.WinRate * 100, results.MaxDrawdown * 100, results.SharpeRatio);
                
                obj.TextArea.Value = res;
                obj.AppRef.updateStatus('Backtest Complete.', [0 0.5 0]);
            catch e
                obj.AppRef.updateStatus(['Error: ' e.message], [0.8 0 0]);
                obj.TextArea.Value = e.message;
            end
        end
    end
end
