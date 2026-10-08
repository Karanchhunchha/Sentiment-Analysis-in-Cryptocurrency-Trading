classdef SentimentAnalysisTab < handle
    properties
        Tab
        AppRef
        TextArea
    end
    
    methods
        function obj = SentimentAnalysisTab(parentGroup, appRef)
            obj.AppRef = appRef;
            obj.Tab = uitab(parentGroup, 'Title', 'Sentiment Analysis');
            obj.buildUI();
        end
        
        function buildUI(obj)
            g = uigridlayout(obj.Tab, [2, 1]);
            uibutton(g, 'Text', 'Run Sentiment Analysis', 'ButtonPushedFcn', @(b,e) obj.runAnalysis());
            obj.TextArea = uitextarea(g, 'Editable', 'off');
        end
        
        function runAnalysis(obj)
            obj.AppRef.updateStatus('Running Sentiment Analysis...');
            try
                engine = SentimentEngine();
                % Ensure historical data is processed
                engine.processHistoricalTweets();
                % Show metrics from the report
                obj.TextArea.Value = 'Sentiment Analysis Complete. Metrics: (See reports/SentimentComparisonReport.html)';
                obj.AppRef.updateStatus('Sentiment Analysis Done.', [0 0.5 0]);
            catch e
                obj.AppRef.updateStatus(['Error: ' e.message], [0.8 0 0]);
            end
        end
    end
end
