classdef App < handle
    % App Orchestrator for the Research Workstation Dashboard
    
    properties
        UIFigure
        TabGroup
        StatusLabel
        
        % Module References
        HomeModule
        SystemHealthModule
        MarketAnalysisModule
        SentimentAnalysisModule
        ForecastModule
        ModelComparisonModule
        FeatureImportanceModule
        PortfolioSimulationModule
        BacktestingModule
        ExperimentsModule
        DataPipelineModule
        DataQualityModule
        ModelManagerModule
        DatabaseModule
        SettingsModule
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
            obj.MarketAnalysisModule = MarketAnalysisTab(obj.TabGroup, obj);
            obj.SentimentAnalysisModule = SentimentAnalysisTab(obj.TabGroup, obj);
            obj.ForecastModule = ForecastTab(obj.TabGroup, obj);
            
            % Modular Tabs (Wire to real backends)
            obj.ModelComparisonModule = ModelComparisonTab(obj.TabGroup, obj);
            obj.FeatureImportanceModule = GenericDiagnosticTab(obj.TabGroup, 'Feature Importance (Diag)', obj, @() ['Feature Importance status: ' char(obj.SystemHealthModule.checkFeatureImportanceStatus())]);
            obj.PortfolioSimulationModule = PortfolioSimulationTab(obj.TabGroup, obj);
            obj.BacktestingModule = BacktestingTab(obj.TabGroup, obj);
            obj.ExperimentsModule = GenericDiagnosticTab(obj.TabGroup, 'Experiments (Diag)', obj, @() 'Experiments (Diag): Comparison scripts available in scripts/ folder.');
            obj.DataPipelineModule = GenericDiagnosticTab(obj.TabGroup, 'Data Pipeline (Diag)', obj, @() ['Data Pipeline status: ' char(obj.SystemHealthModule.checkDataPipelineStatus())]);
            obj.DataQualityModule = GenericDiagnosticTab(obj.TabGroup, 'Data Quality (Diag)', obj, @() ['Data Quality analysis: ' char(obj.SystemHealthModule.checkDataQualityStatus())]);
            obj.ModelManagerModule = GenericDiagnosticTab(obj.TabGroup, 'Model Manager (Diag)', obj, @() ['Model Manager status: ' char(obj.SystemHealthModule.checkModelStatus())]);
            obj.DatabaseModule = GenericDiagnosticTab(obj.TabGroup, 'Database (Diag)', obj, @() ['Database status: ' char(obj.SystemHealthModule.checkDatabaseStatus())]);
            
            % System Health Tab
            obj.SystemHealthModule = SystemHealthTab(obj.TabGroup, obj);
            
            % Settings Tab
            obj.SettingsModule = uitab(obj.TabGroup, 'Title', 'Settings');
            cfg = ConfigManager.getEnv();
            apiKey = cfg('ALPHAVANTAGE_API_KEY');
            apiKeyMasked = 'NOT CONFIGURED';
            if ~isempty(apiKey) && ~strcmp(apiKey, 'your_api_key_here')
                apiKeyMasked = 'CONFIGURED';
            end
            txt = sprintf('Configuration:\nAPI Key: %s\nWorking Dir: %s', ...
                apiKeyMasked, pwd);
            uilabel(obj.SettingsModule, 'Text', txt, ...
                    'Position', [50 350 400 100], 'FontSize', 14);

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
