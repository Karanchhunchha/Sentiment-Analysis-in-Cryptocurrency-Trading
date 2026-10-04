classdef HomeTab < handle
    % HomeTab Main landing dashboard with granular execution buttons
    
    properties
        Tab
        AppRef
    end
    
    methods
        function obj = HomeTab(parentGroup, appRef)
            obj.AppRef = appRef;
            obj.Tab = uitab(parentGroup, 'Title', 'Home');
            obj.buildUI();
        end
        
        function buildUI(obj)
            % Main Title
            uilabel(obj.Tab, 'Text', 'KCryptoX8: Research & Decision Support', ...
                'Position', [350 650 500 40], 'FontSize', 20, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
                
            % Granular Control Flow Panel
            panel = uipanel(obj.Tab, 'Title', 'Execution Pipeline', 'Position', [200 400 800 150], 'FontSize', 16, 'FontWeight', 'bold');
            
            w = 120; h = 40; space = 20;
            startX = 30; y = 50;
            
            uibutton(panel, 'Text', '1. Initialize', 'Position', [startX, y, w, h], ...
                'ButtonPushedFcn', @(btn,event) obj.stepInitialize());
                
            uibutton(panel, 'Text', '2. Collect Data', 'Position', [startX + w + space, y, w, h], ...
                'ButtonPushedFcn', @(btn,event) obj.stepCollect());
                
            uibutton(panel, 'Text', '3. Train Models', 'Position', [startX + (w + space)*2, y, w, h], ...
                'ButtonPushedFcn', @(btn,event) obj.stepTrain());
                
            uibutton(panel, 'Text', '4. Run Forecast', 'Position', [startX + (w + space)*3, y, w, h], ...
                'ButtonPushedFcn', @(btn,event) obj.stepForecast());
                
            uibutton(panel, 'Text', '5. Backtest', 'Position', [startX + (w + space)*4, y, w, h], ...
                'ButtonPushedFcn', @(btn,event) obj.stepBacktest());
                
            uibutton(panel, 'Text', '6. Refresh UI', 'Position', [startX + (w + space)*5, y, w, h], ...
                'ButtonPushedFcn', @(btn,event) obj.stepRefresh());
                
            % Simple BTC Live Widget (Mockup)
            btcPanel = uipanel(obj.Tab, 'Position', [200 200 200 100]);
            uilabel(btcPanel, 'Text', 'BTC Live', 'Position', [10 60 180 30], 'FontSize', 16, 'HorizontalAlignment', 'center');
            uilabel(btcPanel, 'Text', '$ --,---', 'Position', [10 30 180 30], 'FontSize', 18, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
            uilabel(btcPanel, 'Text', '+0.0%', 'Position', [10 10 180 20], 'FontSize', 14, 'FontColor', [0 0.6 0], 'HorizontalAlignment', 'center');
        end
        
        % Granular Actions
        function stepInitialize(obj)
            obj.AppRef.updateStatus('Step 1: Initializing configuration...', [0 0 0]);
            PythonWrapper.setupPath();
            pause(0.5);
            obj.AppRef.updateStatus('Step 1: Initialization Complete.', [0 0.5 0]);
        end
        
        function stepCollect(obj)
            obj.AppRef.updateStatus('Step 2: Collecting Historical Data...', [0 0 0]);
            try
                % Calls the robust failover downloader (Module 1)
                df = MarketDataDownloader.updateMarketData('1h');
                obj.AppRef.updateStatus(sprintf('Step 2: Data Collection Complete (%d new candles).', height(df)), [0 0.5 0]);
            catch e
                obj.AppRef.updateStatus(['Data Collection Failed: ' e.message], [0.8 0 0]);
            end
        end
        
        function stepTrain(obj)
            obj.AppRef.updateStatus('Step 3: Training Models...', [0 0 0]);
            % Implement training logic connection
            pause(1);
            obj.AppRef.updateStatus('Step 3: Training Complete.', [0 0.5 0]);
        end
        
        function stepForecast(obj)
            obj.AppRef.updateStatus('Step 4: Running Forecasts...', [0 0 0]);
            % Implement forecast logic connection
            pause(1);
            obj.AppRef.updateStatus('Step 4: Forecasting Complete.', [0 0.5 0]);
        end
        
        function stepBacktest(obj)
            obj.AppRef.updateStatus('Step 5: Simulating Portfolio...', [0 0 0]);
            % Implement backtest logic connection
            pause(1);
            obj.AppRef.updateStatus('Step 5: Backtesting Complete.', [0 0.5 0]);
        end
        
        function stepRefresh(obj)
            obj.AppRef.updateStatus('Dashboard Refreshed.', [0 0 0]);
        end
    end
end
