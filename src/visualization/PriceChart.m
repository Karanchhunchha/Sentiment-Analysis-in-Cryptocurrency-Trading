classdef PriceChart < handle
    % PriceChart handles the rendering of candlesticks, MAs, and price action overlays
    
    properties (Access = private)
        AxesHandle
        
        % Candlestick graphics handles
        BullishBodies
        BearishBodies
        BullishWicks
        BearishWicks
        
        % Moving Averages
        SMA20Line
        SMA50Line
        EMA20Line
        EMA50Line
    end
    
    methods
        function obj = PriceChart(ax)
            obj.AxesHandle = ax;
            ChartTheme.applyToAxes(ax);
            title(ax, 'BTC/USDT Price Action', 'Color', ChartTheme.TextColor);
            ylabel(ax, 'Price (USDT)', 'Color', ChartTheme.TextColor);
            
            % Initialize empty patches/lines for candlesticks
            obj.BullishWicks = line(ax, NaN, NaN, 'Color', ChartTheme.BullishCandle, 'LineWidth', 1);
            obj.BearishWicks = line(ax, NaN, NaN, 'Color', ChartTheme.BearishCandle, 'LineWidth', 1);
            obj.BullishBodies = patch(ax, NaN, NaN, ChartTheme.BullishCandle, 'EdgeColor', 'none');
            obj.BearishBodies = patch(ax, NaN, NaN, ChartTheme.BearishCandle, 'EdgeColor', 'none');
            
            % Initialize empty lines for MAs
            obj.SMA20Line = plot(ax, NaN, NaN, 'Color', ChartTheme.SMA20Color, 'LineWidth', 1.2, 'DisplayName', 'SMA 20');
            obj.SMA50Line = plot(ax, NaN, NaN, 'Color', ChartTheme.SMA50Color, 'LineWidth', 1.5, 'DisplayName', 'SMA 50');
            obj.EMA20Line = plot(ax, NaN, NaN, 'Color', ChartTheme.EMA20Color, 'LineWidth', 1.2, 'DisplayName', 'EMA 20');
            obj.EMA50Line = plot(ax, NaN, NaN, 'Color', ChartTheme.EMA50Color, 'LineWidth', 1.5, 'DisplayName', 'EMA 50');
        end
        
        function update(obj, dataTable)
            if isempty(dataTable) || height(dataTable) == 0
                return;
            end
            
            times = dataTable.Time;
            if isdatetime(times)
                xData = datenum(times)';
            else
                xData = 1:height(dataTable);
            end
            
            % Extract OHLC
            O = dataTable.Open';
            H = dataTable.High';
            L = dataTable.Low';
            C = dataTable.Close';
            
            % Determine Bullish / Bearish
            isBull = C >= O;
            isBear = C < O;
            
            % Width of candle bodies (roughly 70% of the median distance between candles)
            if length(xData) > 1
                bodyWidth = median(diff(xData)) * 0.35;
            else
                bodyWidth = 0.5;
            end
            
            % Update Wicks (Using NaN separators for single line object)
            obj.updateWicks(obj.BullishWicks, xData(isBull), H(isBull), L(isBull));
            obj.updateWicks(obj.BearishWicks, xData(isBear), H(isBear), L(isBear));
            
            % Update Bodies (Using patches)
            obj.updateBodies(obj.BullishBodies, xData(isBull), O(isBull), C(isBull), bodyWidth);
            obj.updateBodies(obj.BearishBodies, xData(isBear), O(isBear), C(isBear), bodyWidth);
            
            % Update MAs if they exist
            if ismember('SMA20', dataTable.Properties.VariableNames); set(obj.SMA20Line, 'XData', xData, 'YData', dataTable.SMA20'); end
            if ismember('SMA50', dataTable.Properties.VariableNames); set(obj.SMA50Line, 'XData', xData, 'YData', dataTable.SMA50'); end
            if ismember('EMA20', dataTable.Properties.VariableNames); set(obj.EMA20Line, 'XData', xData, 'YData', dataTable.EMA20'); end
            if ismember('EMA50', dataTable.Properties.VariableNames); set(obj.EMA50Line, 'XData', xData, 'YData', dataTable.EMA50'); end
            
            % Format X-Axis for datetimes
            if isdatetime(times)
                datetick(obj.AxesHandle, 'x', 'keeplimits');
            end
            
            % Update Axes Limits
            xLimMin = min(xData);
            if length(xData) > VisualizationConfig.MaxHistoryLength
                xLimMin = xData(end - VisualizationConfig.MaxHistoryLength + 1);
            end
            % Add some margin to the right for future predictions
            predSteps = max(VisualizationConfig.ForecastHorizons.Steps);
            if isdatetime(times)
                % 15 minutes per candle in datenum is roughly 15/(24*60)
                xMargin = (15 / 1440) * (predSteps + 2);
            else
                xMargin = predSteps + 2;
            end
            
            xlim(obj.AxesHandle, [xLimMin, xData(end) + xMargin]);
        end
    end
    
    methods (Access = private)
        function updateWicks(~, lineObj, x, h, l)
            if isempty(x)
                set(lineObj, 'XData', NaN, 'YData', NaN);
                return;
            end
            % Create X and Y arrays with NaN separators: [x1, x1, NaN, x2, x2, NaN...]
            X = [x; x; nan(1, length(x))];
            Y = [h; l; nan(1, length(x))];
            set(lineObj, 'XData', X(:), 'YData', Y(:));
        end
        
        function updateBodies(~, patchObj, x, o, c, w)
            if isempty(x)
                set(patchObj, 'XData', NaN, 'YData', NaN);
                return;
            end
            % Create vertices for patches (4 points per rectangle)
            X = [x-w; x-w; x+w; x+w];
            Y = [o; c; c; o];
            set(patchObj, 'XData', X, 'YData', Y);
        end
    end
end
