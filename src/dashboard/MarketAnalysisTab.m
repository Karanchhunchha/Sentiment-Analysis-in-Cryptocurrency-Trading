classdef MarketAnalysisTab < handle
    properties
        Tab
        AppRef
        Chart
        Data
    end
    
    methods
        function obj = MarketAnalysisTab(parentGroup, appRef)
            obj.AppRef = appRef;
            obj.Tab = uitab(parentGroup, 'Title', 'Market Analysis');
            obj.buildUI();
            obj.loadData();
        end
        
        function buildUI(obj)
            g = uigridlayout(obj.Tab, [2, 1]);
            g.RowHeight = {40, '1x'};
            
            uibutton(g, 'Text', 'Refresh Market Data', 'ButtonPushedFcn', @(btn,evt) obj.loadData());
            
            axes = uiaxes(g);
            obj.Chart = PriceChart(axes);
        end
        
        function loadData(obj)
            obj.AppRef.updateStatus('Loading Market Data...');
            try
                loader = PriceDataLoader('BTCUSDT', '1h');
                obj.Data = loader.fetchRecentHistory(200);
                obj.Data = IndicatorEngine.calculateAll(obj.Data);
                
                % Rename for PriceChart compatibility
                if ismember('SMA_20', obj.Data.Properties.VariableNames)
                    obj.Data.Properties.VariableNames{'SMA_20'} = 'SMA20';
                    obj.Data.Properties.VariableNames{'SMA_50'} = 'SMA50';
                    obj.Data.Properties.VariableNames{'EMA_20'} = 'EMA20';
                    obj.Data.Properties.VariableNames{'EMA_50'} = 'EMA50';
                end
                
                obj.Chart.update(obj.Data);
                drawnow; % Ensure UI updates
                obj.AppRef.updateStatus('Market Data Loaded.', [0 0.5 0]);
            catch e
                obj.AppRef.updateStatus(['Error: ' e.message], [0.8 0 0]);
            end
        end
    end
end
