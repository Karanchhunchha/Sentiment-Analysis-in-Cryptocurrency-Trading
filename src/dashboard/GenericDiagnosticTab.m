classdef GenericDiagnosticTab < handle
    properties
        Tab
        AppRef
        TextArea
        Handler
    end
    
    methods
        function obj = GenericDiagnosticTab(parentGroup, title, appRef, handler)
            obj.AppRef = appRef;
            obj.Handler = handler;
            obj.Tab = uitab(parentGroup, 'Title', title);
            obj.buildUI();
        end
        
        function buildUI(obj)
            g = uigridlayout(obj.Tab, [2, 1]);
            g.RowHeight = {40, '1x'};
            uibutton(g, 'Text', 'Run Diagnostic', 'ButtonPushedFcn', @(b,e) obj.run());
            obj.TextArea = uitextarea(g, 'Editable', 'off');
        end
        
        function run(obj)
            obj.AppRef.updateStatus('Running...');
            try
                result = obj.Handler();
                obj.TextArea.Value = string(result);
                obj.AppRef.updateStatus('Complete.', [0 0.5 0]);
            catch e
                obj.AppRef.updateStatus(['Error: ' e.message], [0.8 0 0]);
            end
        end
    end
end
