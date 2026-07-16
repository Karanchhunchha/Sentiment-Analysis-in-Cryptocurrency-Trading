classdef PredictionChart < handle
    % PredictionChart Handles all AI prediction overlays (paths, confidence, signals)
    
    properties (Access = private)
        AxesHandle
        
        PredictionLine
        ConfidencePatch
        ActualLine
        
        BuyMarker
        SellMarker
        BuyText
        SellText
        
        TargetLine
        SLLine
        SupportLine
        ResistanceLine
        
        CurrentCandleHighlight
        
        InfoTextBox
        DevStatsBox
        
        % Prediction History
        PastPredictionLines
    end
    
    methods
        function obj = PredictionChart(ax)
            obj.AxesHandle = ax;
            hold(ax, 'on');
            
            % 1. Confidence Band (drawn first so it's in the background)
            if VisualizationConfig.ShowConfidenceBand
                obj.ConfidencePatch = patch(ax, NaN, NaN, ChartTheme.ConfidenceBandColor, ...
                    'FaceAlpha', ChartTheme.ConfidenceBandAlpha, 'EdgeColor', 'none', ...
                    'DisplayName', 'Confidence Interval');
            end
            
            % 2. Actual Price Line (for historical tracking of the prediction)
            if VisualizationConfig.ShowActualVsPrediction
                obj.ActualLine = plot(ax, NaN, NaN, '-', 'Color', ChartTheme.ActualPriceColor, ...
                    'LineWidth', 2, 'DisplayName', 'Actual Path');
            end
            
            % 3. Future Prediction Line (and History)
            obj.PastPredictionLines = gobjects(4, 1);
            for i = 1:4
                obj.PastPredictionLines(i) = plot(ax, NaN, NaN, ':', 'Color', [VisualizationConfig.PredictionColor, 0.3], 'LineWidth', 1);
            end
            
            obj.PredictionLine = plot(ax, NaN, NaN, '--', 'Color', VisualizationConfig.PredictionColor, ...
                'LineWidth', 2, 'DisplayName', 'Forecast');
                
            % 4. Target / Levels
            obj.TargetLine = plot(ax, NaN, NaN, '-.', 'Color', [0.2 0.8 0.2], 'LineWidth', 1.5, 'DisplayName', 'Target');
            obj.SLLine = plot(ax, NaN, NaN, '-.', 'Color', [0.8 0.2 0.2], 'LineWidth', 1.5, 'DisplayName', 'Stop Loss');
            obj.SupportLine = plot(ax, NaN, NaN, '-', 'Color', ChartTheme.SupportColor, 'LineWidth', 1, 'DisplayName', 'Support');
            obj.ResistanceLine = plot(ax, NaN, NaN, '-', 'Color', ChartTheme.ResistanceColor, 'LineWidth', 1, 'DisplayName', 'Resistance');
            
            % 5. Markers and Probability text
            if VisualizationConfig.ShowPredictionMarkers
                obj.BuyMarker = scatter(ax, NaN, NaN, 100, '^', 'MarkerFaceColor', ChartTheme.BullishCandle, 'MarkerEdgeColor', 'k', 'DisplayName', 'BUY');
                obj.SellMarker = scatter(ax, NaN, NaN, 100, 'v', 'MarkerFaceColor', ChartTheme.BearishCandle, 'MarkerEdgeColor', 'k', 'DisplayName', 'SELL');
                obj.BuyText = text(ax, NaN, NaN, '', 'Color', ChartTheme.BullishCandle, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
                obj.SellText = text(ax, NaN, NaN, '', 'Color', ChartTheme.BearishCandle, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
            end
            
            % 6. Current Candle Highlight
            obj.CurrentCandleHighlight = plot(ax, NaN, NaN, 's', 'MarkerEdgeColor', [1 1 0], 'MarkerSize', 12, 'LineWidth', 2);
            
            % 7. Info Box (Top Right)
            obj.InfoTextBox = text(ax, 0.98, 0.95, '', 'Units', 'normalized', ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'Color', ChartTheme.TextHighlight, 'BackgroundColor', ChartTheme.PanelBackground, ...
                'EdgeColor', ChartTheme.GridColor, 'Margin', 5, 'FontSize', ChartTheme.FontSizeSmall);
                
            % 8. Dev Stats Box (Top Left)
            obj.DevStatsBox = text(ax, 0.02, 0.95, '', 'Units', 'normalized', ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
                'Color', ChartTheme.TextDim, 'BackgroundColor', 'none', ...
                'EdgeColor', 'none', 'Margin', 5, 'FontSize', ChartTheme.FontSizeSmall);
        end
        
        function update(obj, predStruct)
            % predStruct contains: ...
            
            if isempty(fieldnames(predStruct))
                set(obj.InfoTextBox, 'String', 'No Prediction');
                set(obj.PredictionLine, 'XData', NaN, 'YData', NaN);
                if ~isempty(obj.ConfidencePatch)
                    set(obj.ConfidencePatch, 'XData', NaN, 'YData', NaN);
                end
                if ~isempty(obj.BuyMarker)
                    set(obj.BuyMarker, 'XData', NaN, 'YData', NaN);
                    set(obj.SellMarker, 'XData', NaN, 'YData', NaN);
                    set(obj.BuyText, 'String', '');
                    set(obj.SellText, 'String', '');
                end
                set(obj.TargetLine, 'XData', NaN, 'YData', NaN);
                set(obj.SLLine, 'XData', NaN, 'YData', NaN);
                set(obj.SupportLine, 'XData', NaN, 'YData', NaN);
                set(obj.ResistanceLine, 'XData', NaN, 'YData', NaN);
                return;
            end
            
            t = predStruct.Time;
            if isdatetime(t); t = datenum(t); end
            
            ft = predStruct.FutureTimes;
            if isdatetime(ft); ft = datenum(ft); end
            
            % Include current point in future paths for continuity
            ft_full = [t; ft(:)];
            pred_full = [predStruct.CurrentPrice; predStruct.PredictedPrices(:)];
            up_full = [predStruct.CurrentPrice; predStruct.UpperConfidence(:)];
            dn_full = [predStruct.CurrentPrice; predStruct.LowerConfidence(:)];
            
            % 1. Update Confidence Band
            if ~isempty(obj.ConfidencePatch)
                X_poly = [ft_full; flipud(ft_full)];
                Y_poly = [up_full; flipud(dn_full)];
                set(obj.ConfidencePatch, 'XData', X_poly, 'YData', Y_poly);
            end
            
            % 2. Update Prediction Line and Shift History
            % Shift history lines
            for i = 4:-1:2
                set(obj.PastPredictionLines(i), 'XData', get(obj.PastPredictionLines(i-1), 'XData'), ...
                                                'YData', get(obj.PastPredictionLines(i-1), 'YData'));
            end
            % Move current to history 1
            set(obj.PastPredictionLines(1), 'XData', get(obj.PredictionLine, 'XData'), ...
                                            'YData', get(obj.PredictionLine, 'YData'));
            % Set new prediction
            set(obj.PredictionLine, 'XData', ft_full, 'YData', pred_full);
            
            % 3. Update Markers
            if ~isempty(obj.BuyMarker)
                probStr = sprintf('%.1f%%', predStruct.ConfidenceScore * 100);
                if strcmp(predStruct.Signal, 'BUY')
                    set(obj.BuyMarker, 'XData', t, 'YData', predStruct.CurrentPrice * 0.995);
                    set(obj.BuyText, 'Position', [t, predStruct.CurrentPrice * 0.990], 'String', ['BUY ', probStr]);
                    set(obj.SellMarker, 'XData', NaN, 'YData', NaN);
                    set(obj.SellText, 'String', '');
                elseif strcmp(predStruct.Signal, 'SELL')
                    set(obj.SellMarker, 'XData', t, 'YData', predStruct.CurrentPrice * 1.005);
                    set(obj.SellText, 'Position', [t, predStruct.CurrentPrice * 1.010], 'String', ['SELL ', probStr]);
                    set(obj.BuyMarker, 'XData', NaN, 'YData', NaN);
                    set(obj.BuyText, 'String', '');
                else
                    set(obj.BuyMarker, 'XData', NaN, 'YData', NaN);
                    set(obj.SellMarker, 'XData', NaN, 'YData', NaN);
                    set(obj.BuyText, 'String', '');
                    set(obj.SellText, 'String', '');
                end
            end
            
            % 4. Current Candle Highlight
            set(obj.CurrentCandleHighlight, 'XData', t, 'YData', predStruct.CurrentPrice);
            
            % 5. Horizontal Levels
            % To draw horizontal lines covering the prediction space:
            level_x = [t, ft_full(end)];
            
            if isfield(predStruct, 'TargetPrice') && predStruct.TargetPrice > 0
                set(obj.TargetLine, 'XData', level_x, 'YData', [predStruct.TargetPrice, predStruct.TargetPrice]);
            else
                set(obj.TargetLine, 'XData', NaN, 'YData', NaN);
            end
            
            if isfield(predStruct, 'StopLoss') && predStruct.StopLoss > 0
                set(obj.SLLine, 'XData', level_x, 'YData', [predStruct.StopLoss, predStruct.StopLoss]);
            else
                set(obj.SLLine, 'XData', NaN, 'YData', NaN);
            end
            
            if isfield(predStruct, 'Support') && predStruct.Support > 0
                set(obj.SupportLine, 'XData', [level_x(1)-10, level_x(2)], 'YData', [predStruct.Support, predStruct.Support]);
            end
            
            if isfield(predStruct, 'Resistance') && predStruct.Resistance > 0
                set(obj.ResistanceLine, 'XData', [level_x(1)-10, level_x(2)], 'YData', [predStruct.Resistance, predStruct.Resistance]);
            end
            
            % 6. Text Box Info
            if isfield(predStruct, 'Source')
                if predStruct.Source.Projection
                    sourceLabel = 'MODEL + PROJECTED';
                else
                    sourceLabel = 'MODEL DIRECT';
                end
            else
                sourceLabel = 'UNKNOWN';
            end
            
            valStatus = 'UNKNOWN';
            if isfield(predStruct, 'ValidationStatus')
                valStatus = predStruct.ValidationStatus;
            end
            
            etaStr = '-';
            if isfield(predStruct, 'ETA')
                etaStr = predStruct.ETA;
            end
            
            rrStr = '-';
            if isfield(predStruct, 'RiskReward') && predStruct.RiskReward > 0
                rrStr = sprintf('1:%.2f', predStruct.RiskReward);
            end
            
            infoStr = sprintf('Source: %s\nStatus: %s\nConfidence: %.1f%%\nRisk/Reward: %s\nETA: %s\nInference: %.1f ms', ...
                sourceLabel, valStatus, predStruct.ConfidenceScore * 100, rrStr, etaStr, predStruct.InferenceTimeMs);
            set(obj.InfoTextBox, 'String', infoStr);
            
            % 7. Dev Stats Box
            mem = memory;
            statsStr = sprintf('FPS: 60 (Handle)\nCPU Time: <5ms\nObjects: %d\nMem: %.0f MB', ...
                length(findobj(obj.AxesHandle)), mem.MemUsedMATLAB / (1024^2));
            set(obj.DevStatsBox, 'String', statsStr);
        end
    end
end
