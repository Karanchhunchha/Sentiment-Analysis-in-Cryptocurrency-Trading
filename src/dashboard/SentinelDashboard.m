%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef SentinelDashboard < handle
    % SentinelDashboard Master UI for the SentinelCrypto Pipeline
    % Completely revamped to display all realistic production values.
    
    properties (Access = private)
        UIFigure
        GridLayout
        DashboardData
        
        % Store handles for rapid updates without redrawing
        LabelMap
    end
    
    methods
        function obj = SentinelDashboard(data)
            obj.DashboardData = data;
            obj.LabelMap = dictionary();
            obj.createUI();
        end
        
        function updateData(obj, newData)
            obj.DashboardData = newData;
            
            % Fast update of UI text fields
            fields = fieldnames(newData);
            for i = 1:length(fields)
                fName = fields{i};
                if isKey(obj.LabelMap, fName)
                    lbl = obj.LabelMap(fName);
                    
                    % Formatting logic based on field type
                    val = newData.(fName);
                    if isnumeric(val)
                        if contains(fName, {'Price', 'Expected', 'SL', 'TP', 'Support', 'Resistance', 'Prediction'}) && ~contains(fName, {'Accuracy', 'Probability', 'Confidence', 'RiskReward'})
                            lbl.Text = sprintf('$%.2f', val);
                        elseif contains(fName, {'Probability', 'Confidence', 'Accuracy'})
                            lbl.Text = sprintf('%.1f%%', val * 100);
                        elseif contains(fName, 'RiskReward')
                            lbl.Text = sprintf('1 : %.2f', val);
                        else
                            lbl.Text = sprintf('%.2f', val);
                        end
                    else
                        lbl.Text = char(val);
                    end
                    
                    % Dynamic coloring for signals/trends
                    if strcmp(fName, 'Trend') || strcmp(fName, 'Signal')
                        if contains(val, 'UP') || contains(val, 'BUY')
                            lbl.FontColor = [0 1 0];
                        elseif contains(val, 'DOWN') || contains(val, 'SELL')
                            lbl.FontColor = [1 0 0];
                        else
                            lbl.FontColor = [1 1 0];
                        end
                    end
                end
            end
            
            drawnow limitrate;
        end
    end
    
    methods (Access = private)
        function createUI(obj)
            % Main Figure
            obj.UIFigure = uifigure('Name', 'SentinelCrypto Production Dashboard', ...
                'Position', [100, 100, 1400, 900], ...
                'Color', [0.08 0.08 0.1]);
            
            % Main Layout (4x4 Grid for denser data)
            obj.GridLayout = uigridlayout(obj.UIFigure, [5, 4]);
            obj.GridLayout.RowHeight = {60, '1x', '1x', '1x', '1x'};
            obj.GridLayout.BackgroundColor = [0.08 0.08 0.1];
            
            % Title
            titleLabel = uilabel(obj.GridLayout, 'Text', 'SENTINELCRYPTO | LIVE PRODUCTION ENGINE', ...
                'FontColor', [0 0.8 1], 'FontSize', 22, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center');
            titleLabel.Layout.Row = 1;
            titleLabel.Layout.Column = [1 4];
            
            %% Row 2: Top Level Price & Signals
            obj.createCard(2, 1, 'CurrentPrice', 'Current Price');
            obj.createCard(2, 2, 'Signal', 'Master Signal');
            obj.createCard(2, 3, 'Trend', 'Market Trend');
            obj.createCard(2, 4, 'Confidence', 'Confidence Level');
            
            %% Row 3: Expectations & Probabilities
            obj.createCard(3, 1, 'ExpectedNextClose', 'Expected Next Close');
            obj.createCard(3, 2, 'ExpectedHigh', 'Expected High');
            obj.createCard(3, 3, 'ExpectedLow', 'Expected Low');
            pGrid = uigridlayout(uigridlayout(obj.GridLayout, [1 1]), [2 1]); pGrid.Layout.Row = 3; pGrid.Layout.Column = 4; pGrid.Padding = [0 0 0 0];
            obj.createCard(1, 1, 'ProbabilityUp', 'Probability UP', pGrid);
            obj.createCard(2, 1, 'ProbabilityDown', 'Probability DOWN', pGrid);
            
            %% Row 4: Risk Management & Support/Resistance
            obj.createCard(4, 1, 'Support', 'Support Level');
            obj.createCard(4, 2, 'Resistance', 'Resistance Level');
            obj.createCard(4, 3, 'SL', 'Stop Loss (SL)');
            
            % TP Grid
            tpGrid = uigridlayout(uigridlayout(obj.GridLayout, [1 1]), [3 1]); tpGrid.Layout.Row = 4; tpGrid.Layout.Column = 4; tpGrid.Padding = [0 0 0 0];
            obj.createCard(1, 1, 'TP1', 'Take Profit 1', tpGrid);
            obj.createCard(2, 1, 'TP2', 'Take Profit 2', tpGrid);
            obj.createCard(3, 1, 'TP3', 'Take Profit 3', tpGrid);
            
            %% Row 5: Metadata & Timestamps
            obj.createCard(5, 1, 'PredictionGenerated', 'Generated At');
            obj.createCard(5, 2, 'PredictionValidUntil', 'Valid Until');
            obj.createCard(5, 3, 'LastModelVersion', 'Model Version');
            obj.createCard(5, 4, 'RiskReward', 'Risk/Reward Ratio');
            
            % Initialize with data
            obj.updateData(obj.DashboardData);
        end
        
        function createCard(obj, row, col, fieldName, titleText, parentOverride)
            if nargin < 6
                parent = obj.GridLayout;
            else
                parent = parentOverride;
            end
            
            pnl = uipanel(parent, 'BackgroundColor', [0.12 0.12 0.15], 'BorderType', 'none');
            pnl.Layout.Row = row;
            pnl.Layout.Column = col;
            
            g = uigridlayout(pnl, [2, 1]);
            g.RowHeight = {'1x', '2x'};
            g.BackgroundColor = [0.12 0.12 0.15];
            
            tlbl = uilabel(g, 'Text', titleText, 'FontColor', [0.7 0.7 0.7], 'FontSize', 12, 'HorizontalAlignment', 'center');
            tlbl.Layout.Row = 1;
            tlbl.Layout.Column = 1;
            
            lbl = uilabel(g, 'Text', '-', 'FontColor', [1 1 1], 'FontSize', 20, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
            lbl.Layout.Row = 2;
            lbl.Layout.Column = 1;
            
            % Store in map for blazing fast updates
            obj.LabelMap(fieldName) = lbl;
        end
    end
end
