classdef ModelComparisonTab < handle
    properties
        Tab, AppRef, TextArea
    end
    
    methods
        function obj = ModelComparisonTab(parentGroup, appRef)
            obj.AppRef = appRef;
            obj.Tab = uitab(parentGroup, 'Title', 'Model Comparison');
            obj.buildUI();
        end
        
        function buildUI(obj)
            g = uigridlayout(obj.Tab, [2, 1]);
            g.RowHeight = {40, '1x'};
            uibutton(g, 'Text', 'Run Comparison', 'ButtonPushedFcn', @(b,e) obj.run());
            obj.TextArea = uitextarea(g, 'Editable', 'off', 'FontName', 'FixedWidth');
        end
        
        function run(obj)
            obj.AppRef.updateStatus('Comparing models...');
            try
                histData = PriceDataLoader('BTCUSDT', '1h').fetchRecentHistory(300);
                comparer = ModelComparer(histData);
                comparer.runComparison(0.8);
                
                % Format table to string
                T = comparer.Results;
                str = '';
                for i = 1:height(T)
                    str = [str, sprintf('%s: RMSE=%.2f, MAE=%.2f, DA=%.2f%%\n', ...
                        T.Model{i}, T.RMSE(i), T.MAE(i), T.DirectionalAccuracy(i))];
                end
                obj.TextArea.Value = str;
                obj.AppRef.updateStatus('Comparison Complete.', [0 0.5 0]);
            catch e
                obj.AppRef.updateStatus(['Error: ' e.message], [0.8 0 0]);
                obj.TextArea.Value = e.message;
            end
        end
    end
end
