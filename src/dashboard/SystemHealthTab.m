classdef SystemHealthTab < handle
    % SystemHealthTab Displays diagnostic information
    
    properties
        Tab
        AppRef
        TextArea
    end
    
    methods
        function obj = SystemHealthTab(parentGroup, appRef)
            obj.AppRef = appRef;
            obj.Tab = uitab(parentGroup, 'Title', 'System Health');
            obj.buildUI();
        end
        
        function buildUI(obj)
            uibutton(obj.Tab, 'Text', 'Run Diagnostics', 'Position', [50 650 150 40], ...
                'ButtonPushedFcn', @(btn,event) obj.runHealthCheckUI());
                
            obj.TextArea = uitextarea(obj.Tab, 'Position', [50 350 500 280], 'Editable', 'off', 'FontSize', 14);
        end
        
        function runHealthCheck(obj)
            obj.AppRef.updateStatus('Running Startup Diagnostics...', [0 0 0]);
            
            status = SystemHealthCheck.runChecks();
            
            if status.IsReady
                obj.AppRef.updateStatus(sprintf('System READY | MATLAB: %s | Python: %s', status.MATLAB, status.Python), [0 0.5 0]);
            end
        end
        
        function runHealthCheckUI(obj)
            status = SystemHealthCheck.runChecks();
            txt = sprintf('MATLAB Toolboxes: %s\nPython Integration: %s\nPostgreSQL: %s\nInternet: %s\nLLM: %s\nLocal Cache: %s', ...
                status.MATLAB, status.Python, status.PostgreSQL, status.Internet, status.LLM, status.LocalCache);
                
            obj.TextArea.Value = txt;
        end
    end
end
