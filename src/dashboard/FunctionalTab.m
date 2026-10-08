classdef FunctionalTab < handle
    properties
        Tab, AppRef, TextArea
        Handler
    end
    
    methods
        function obj = FunctionalTab(parentGroup, title, appRef, handler)
            obj.AppRef = appRef;
            obj.Handler = handler;
            obj.Tab = uitab(parentGroup, 'Title', title);
            obj.buildUI();
        end
        
        function buildUI(obj)
            g = uigridlayout(obj.Tab, [2, 1]);
            g.RowHeight = {40, '1x'};
            uibutton(g, 'Text', 'Execute Pipeline', 'ButtonPushedFcn', @(b,e) obj.run());
            obj.TextArea = uitextarea(g, 'Editable', 'off', 'FontName', 'FixedWidth');
        end
        
        function run(obj)
            obj.AppRef.updateStatus('Executing...');
            try
                % The handler should execute and return a string (already formatted as report)
                result = obj.Handler();
                obj.TextArea.Value = string(result);
                obj.AppRef.updateStatus('Complete.', [0 0.5 0]);
            catch e
                obj.AppRef.updateStatus(['Error: ' e.message], [0.8 0 0]);
                obj.TextArea.Value = ['Error: ' e.message];
            end
        end
    end
end
