classdef ChartExporter
    % ChartExporter handles saving the dashboard to various formats
    
    methods (Static)
        function exportDashboard(figHandle, filenameBase)
            if ~exist('reports', 'dir')
                mkdir('reports');
            end
            
            basePath = fullfile('reports', filenameBase);
            
            % Save as PNG
            try
                exportgraphics(figHandle, [basePath, '.png'], 'Resolution', 300);
            catch
                % Fallback
                saveas(figHandle, [basePath, '.png']);
            end
            
            % Save as PDF
            try
                exportgraphics(figHandle, [basePath, '.pdf'], 'ContentType', 'vector');
            catch
                % Fallback
                saveas(figHandle, [basePath, '.pdf']);
            end
            
            % Save as FIG
            savefig(figHandle, [basePath, '.fig']);
            
            fprintf('[ChartExporter] Saved %s to PNG, PDF, and FIG.\n', filenameBase);
        end
    end
end
