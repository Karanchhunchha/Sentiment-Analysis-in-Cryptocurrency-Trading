%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef App < handle
    % App Orchestrator for the Research Workstation Dashboard
    
    properties
        UIFigure
        TabGroup
        StatusLabel
        
        % Module References
        HomeModule
        SystemHealthModule
        % other modules will be added here
    end
    
    methods
        function obj = App()
            obj.createUI();
            obj.SystemHealthModule.runHealthCheck();
        end
        
        function createUI(obj)
            % Main Frame
            obj.UIFigure = uifigure('Name', 'SentinelCrypto Research Workstation v4.0', 'Position', [100 100 1200 800]);
            
            % Status Bar
            obj.StatusLabel = uilabel(obj.UIFigure, 'Text', 'Initializing System...', ...
                'Position', [10 10 1180 30], 'FontWeight', 'bold', 'FontSize', 14);
            
            % Tab Group
            obj.TabGroup = uitabgroup(obj.UIFigure, 'Position', [10 50 1180 740]);
            
            % Initialize Modular Tabs
            obj.HomeModule = HomeTab(obj.TabGroup, obj);
            
            % Create placeholders for unbuilt tabs per PRD
            placeholders = {'Market Analysis', 'Sentiment Analysis', 'Forecast', 'Model Comparison', ...
                            'Feature Importance', 'Portfolio Simulation', 'Backtesting', ...
                            'Experiments', 'Data Pipeline', 'Data Quality', 'Model Manager', 'Database'};
                            
            for i = 1:length(placeholders)
                t = uitab(obj.TabGroup, 'Title', placeholders{i});
                uilabel(t, 'Text', sprintf('--- %s Module ---', placeholders{i}), ...
                    'Position', [400 350 400 40], 'FontSize', 18, 'HorizontalAlignment', 'center');
            end
            
            % System Health Tab
            obj.SystemHealthModule = SystemHealthTab(obj.TabGroup, obj);
            
            % Settings Tab
            t = uitab(obj.TabGroup, 'Title', 'Settings');
            uilabel(t, 'Text', '--- Settings Module ---', ...
                    'Position', [400 350 400 40], 'FontSize', 18, 'HorizontalAlignment', 'center');
        end
        
        function updateStatus(obj, text, color)
            obj.StatusLabel.Text = text;
            if nargin > 2
                obj.StatusLabel.FontColor = color;
            end
            drawnow;
        end
    end
end
