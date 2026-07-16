classdef PerformanceProfiler < handle
    % PerformanceProfiler Tracks and reports system performance metrics
    
    properties
        StartTime
        RenderTimes = []
        InferenceTimes = []
        TickCount = 0
    end
    
    methods
        function obj = PerformanceProfiler()
            obj.StartTime = tic;
        end
        
        function logTick(obj, renderTimeMs, inferenceTimeMs)
            obj.RenderTimes = [obj.RenderTimes, renderTimeMs];
            obj.InferenceTimes = [obj.InferenceTimes, inferenceTimeMs];
            obj.TickCount = obj.TickCount + 1;
        end
        
        function report = generateReport(obj)
            mem = memory;
            
            elapsedSec = toc(obj.StartTime);
            
            if obj.TickCount > 0
                avgFps = obj.TickCount / elapsedSec;
                avgRender = mean(obj.RenderTimes);
                avgInference = mean(obj.InferenceTimes);
            else
                avgFps = 0;
                avgRender = 0;
                avgInference = 0;
            end
            
            report = struct(...
                'AverageFPS', avgFps, ...
                'AverageRenderTimeMs', avgRender, ...
                'AverageInferenceTimeMs', avgInference, ...
                'MemoryUsageMB', mem.MemUsedMATLAB / (1024^2), ...
                'MATLABVersion', version, ...
                'Toolboxes', 'Financial, Deep Learning, Statistics' ... % Mocked static string for demonstration
            );
        end
        
        function printReport(obj)
            r = obj.generateReport();
            fprintf('\n--- Performance Report ---\n');
            fprintf('Avg FPS: %.2f\n', r.AverageFPS);
            fprintf('Avg Render Time: %.2f ms\n', r.AverageRenderTimeMs);
            fprintf('Avg Inference Time: %.2f ms\n', r.AverageInferenceTimeMs);
            fprintf('Memory Usage: %.0f MB\n', r.MemoryUsageMB);
            fprintf('MATLAB Version: %s\n', r.MATLABVersion);
            fprintf('--------------------------\n');
        end
    end
end
