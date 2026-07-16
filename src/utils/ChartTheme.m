classdef ChartTheme
    % ChartTheme defines the visual style for the Institutional Dashboard
    
    properties (Constant)
        % Backgrounds
        Background = [0.05, 0.06, 0.08];
        PanelBackground = [0.08, 0.09, 0.12];
        GridColor = [0.15, 0.16, 0.2];
        
        % Text
        TextColor = [0.85, 0.85, 0.85];
        TextDim = [0.6, 0.6, 0.6];
        TextHighlight = [1, 1, 1];
        
        % Candlesticks
        BullishCandle = [0.15, 0.75, 0.45];
        BearishCandle = [0.95, 0.25, 0.35];
        DojiCandle = [0.7, 0.7, 0.7];
        
        % Moving Averages
        SMA20Color = [0.9, 0.7, 0.1];
        SMA50Color = [0.8, 0.4, 0.1];
        EMA20Color = [0.2, 0.8, 0.9];
        EMA50Color = [0.5, 0.2, 0.8];
        VWAPColor = [0.9, 0.2, 0.7];
        
        % Predictions
        ActualPriceColor = [0.2, 0.9, 0.4];
        PredictionLineColor = [0.2, 0.6, 1.0];
        ForecastLineColor = [1.0, 0.6, 0.1];
        ConfidenceBandColor = [0.3, 0.3, 0.4];
        ConfidenceBandAlpha = 0.3;
        
        % SMC and Overlays
        SupportColor = [0.1, 0.6, 0.2];
        ResistanceColor = [0.8, 0.2, 0.2];
        BOSColor = [0.5, 0.5, 0.9];
        CHoCHColor = [0.8, 0.4, 0.8];
        LiquidityColor = [0.9, 0.8, 0.1];
        
        % Fonts
        FontName = 'Arial';
        FontSizeSmall = 9;
        FontSizeMedium = 11;
        FontSizeLarge = 14;
        FontSizeTitle = 16;
    end
    
    methods (Static)
        function applyToAxes(ax)
            % Apply the dark institutional theme to a given MATLAB axes object
            ax.Color = ChartTheme.PanelBackground;
            ax.XColor = ChartTheme.TextColor;
            ax.YColor = ChartTheme.TextColor;
            ax.GridColor = ChartTheme.GridColor;
            ax.GridAlpha = 0.5;
            ax.XGrid = 'on';
            ax.YGrid = 'on';
            ax.FontName = ChartTheme.FontName;
            ax.FontSize = ChartTheme.FontSizeSmall;
            hold(ax, 'on');
        end
    end
end
