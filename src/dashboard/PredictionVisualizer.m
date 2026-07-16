classdef PredictionVisualizer < handle
    % PredictionVisualizer Main UI Controller for Institutional Edition
    
    properties (Access = private)
        UIFigure
        GridLayout
        PriceAxes
        IndicatorAxes
        PriceChartObj
        PredictionChartObj
        VolumeBarObj
        
        DataHistory % Buffer of incoming data
    end
    
    methods
        function obj = PredictionVisualizer()
            obj.createUI();
            obj.DataHistory = table();
        end
        
        function initializeData(obj, histData)
            % Ensure standard variable names
            if ismember('Date', histData.Properties.VariableNames)
                histData.Properties.VariableNames{'Date'} = 'Time';
            end
            
            % Seed the visualizer with historical data
            obj.DataHistory = histData;
            
            % Trim if it exceeds maximum
            if height(obj.DataHistory) > VisualizationConfig.MaxHistoryLength
                obj.DataHistory = obj.DataHistory(end-VisualizationConfig.MaxHistoryLength+1:end, :);
            end
            
            % Update submodules
            obj.PriceChartObj.update(obj.DataHistory);
            obj.updateVolume();
            drawnow limitrate;
        end
        
        function update(obj, newDataRow, predStruct)
            % Append data
            if isempty(obj.DataHistory)
                obj.DataHistory = newDataRow;
            else
                obj.DataHistory = [obj.DataHistory; newDataRow];
                % Maintain max history length
                if height(obj.DataHistory) > VisualizationConfig.MaxHistoryLength
                    obj.DataHistory = obj.DataHistory(end-VisualizationConfig.MaxHistoryLength+1:end, :);
                end
            end
            
            % Update submodules
            obj.PriceChartObj.update(obj.DataHistory);
            obj.updateVolume();
            
            if nargin >= 3 && ~isempty(predStruct)
                obj.PredictionChartObj.update(predStruct);
            end
            
            % Force MATLAB to flush graphics queue without blocking
            drawnow limitrate;
        end
        
        function exportCurrent(obj, filenameBase)
            ChartExporter.exportDashboard(obj.UIFigure, filenameBase);
        end
        
        function delete(obj)
            if isvalid(obj.UIFigure)
                close(obj.UIFigure);
            end
        end
    end
    
    methods (Access = private)
        function createUI(obj)
            obj.UIFigure = figure('Name', 'SentinelCrypto Prediction Visualizer', ...
                'Color', ChartTheme.Background, ...
                'Position', [200, 200, 1200, 800], ...
                'MenuBar', 'none', ...
                'ToolBar', 'figure');
            
            % Create tiled layout for modular panels
            obj.GridLayout = tiledlayout(obj.UIFigure, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
            
            % Panel 1: Price Chart (Takes up 2/4 of the space)
            obj.PriceAxes = nexttile(obj.GridLayout, 1, [2 1]);
            obj.PriceChartObj = PriceChart(obj.PriceAxes);
            obj.PredictionChartObj = PredictionChart(obj.PriceAxes);
            
            % Panel 2: Indicators (Volume / RSI) - placeholder for now
            obj.IndicatorAxes = nexttile(obj.GridLayout, 3, [1 1]);
            ChartTheme.applyToAxes(obj.IndicatorAxes);
            title(obj.IndicatorAxes, 'Volume & Indicators', 'Color', ChartTheme.TextColor);
            
            % Initialize volume bar
            obj.VolumeBarObj = bar(obj.IndicatorAxes, NaN, NaN, 'FaceColor', [0.4 0.4 0.6], 'EdgeColor', 'none');
            
            % Make x-axes linked
            linkaxes([obj.PriceAxes, obj.IndicatorAxes], 'x');
        end
        
        function updateVolume(obj)
            if ~isempty(obj.DataHistory) && ismember('Volume', obj.DataHistory.Properties.VariableNames)
                % Extract the Time column (could be datetime)
                times = obj.DataHistory.Time;
                if isdatetime(times)
                    set(obj.VolumeBarObj, 'XData', datenum(times), 'YData', obj.DataHistory.Volume);
                    datetick(obj.IndicatorAxes, 'x', 'keeplimits');
                else
                    set(obj.VolumeBarObj, 'XData', 1:height(obj.DataHistory), 'YData', obj.DataHistory.Volume);
                end
            end
        end
    end
end
