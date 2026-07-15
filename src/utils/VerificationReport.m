%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef VerificationReport < handle
    % VerificationReport Generates the exhaustive 39-metric institutional
    % HTML report mandated for MathWorks Challenge #239.
    
    properties
        ReportFile
        Metrics
    end
    
    methods
        function obj = VerificationReport(outputDir)
            if nargin < 1; outputDir = 'reports'; end
            if ~exist(outputDir, 'dir')
                mkdir(outputDir);
            end
            obj.ReportFile = fullfile(outputDir, 'SentinelCrypto_Verification_Report.html');
            obj.Metrics = struct();
        end
        
        function addMetric(obj, category, name, value, isPassed)
            % Accumulate metrics
            if ~isfield(obj.Metrics, category)
                obj.Metrics.(category) = struct();
            end
            obj.Metrics.(category).(matlab.lang.makeValidName(name)) = struct('Value', value, 'Passed', isPassed);
        end
        
        function score = calculateReadiness(obj)
            % 100% requires all tests to pass
            cats = fieldnames(obj.Metrics);
            total = 0;
            passed = 0;
            
            for i = 1:numel(cats)
                metricsList = fieldnames(obj.Metrics.(cats{i}));
                for j = 1:numel(metricsList)
                    total = total + 1;
                    if obj.Metrics.(cats{i}).(metricsList{j}).Passed
                        passed = passed + 1;
                    end
                end
            end
            
            if total == 0
                score = 0;
            else
                score = (passed / total) * 100;
            end
        end
        
        function generateHTML(obj)
            fid = fopen(obj.ReportFile, 'w');
            
            readiness = obj.calculateReadiness();
            
            % Write HTML Header
            fprintf(fid, '<!DOCTYPE html>\n<html>\n<head>\n');
            fprintf(fid, '<title>Institutional Verification Report - SentinelCrypto</title>\n');
            fprintf(fid, '<style>\n');
            fprintf(fid, 'body { font-family: Arial, sans-serif; background: #0b0c10; color: #c5c6c7; margin: 40px; }\n');
            fprintf(fid, 'h1 { color: #66fcf1; }\n');
            fprintf(fid, 'h2 { color: #45a29e; border-bottom: 1px solid #1f2833; padding-bottom: 10px; }\n');
            fprintf(fid, 'table { border-collapse: collapse; width: 100%%; margin-bottom: 30px; }\n');
            fprintf(fid, 'th, td { padding: 12px; text-align: left; border: 1px solid #1f2833; }\n');
            fprintf(fid, 'th { background-color: #1f2833; color: #66fcf1; }\n');
            fprintf(fid, '.pass { color: #00ff00; font-weight: bold; }\n');
            fprintf(fid, '.fail { color: #ff0000; font-weight: bold; }\n');
            fprintf(fid, '.score { font-size: 2em; color: %s; }\n', obj.getColor(readiness));
            fprintf(fid, '</style>\n</head>\n<body>\n');
            
            fprintf(fid, '<h1>SentinelCrypto Verification Report (MathWorks Challenge #239)</h1>\n');
            fprintf(fid, '<p>Generated on: %s</p>\n', char(datetime('now')));
            
            fprintf(fid, '<h2>Institutional Readiness Score</h2>\n');
            fprintf(fid, '<p class="score">%.1f%%</p>\n', readiness);
            if readiness == 100
                fprintf(fid, '<p class="pass">STATUS: CLEARED FOR INSTITUTIONAL DEPLOYMENT</p>\n');
            else
                fprintf(fid, '<p class="fail">STATUS: VALIDATION INCOMPLETE. DO NOT DEPLOY.</p>\n');
            end
            
            cats = fieldnames(obj.Metrics);
            for i = 1:numel(cats)
                catName = strrep(cats{i}, '_', ' ');
                fprintf(fid, '<h2>%s</h2>\n', catName);
                fprintf(fid, '<table>\n<tr><th>Metric</th><th>Value</th><th>Status</th></tr>\n');
                
                metricsList = fieldnames(obj.Metrics.(cats{i}));
                for j = 1:numel(metricsList)
                    mName = strrep(metricsList{j}, '_', ' ');
                    mVal = obj.Metrics.(cats{i}).(metricsList{j}).Value;
                    mPass = obj.Metrics.(cats{i}).(metricsList{j}).Passed;
                    
                    if mPass; statusStr = '<span class="pass">PASS</span>'; else; statusStr = '<span class="fail">FAIL</span>'; end
                    
                    if isnumeric(mVal)
                        valStr = num2str(mVal);
                    else
                        valStr = mVal;
                    end
                    
                    fprintf(fid, '<tr><td>%s</td><td>%s</td><td>%s</td></tr>\n', mName, valStr, statusStr);
                end
                fprintf(fid, '</table>\n');
            end
            
            fprintf(fid, '</body>\n</html>\n');
            fclose(fid);
            
            Logger.info(sprintf('Verification Report Generated: %s', obj.ReportFile));
        end
        
        function col = getColor(~, score)
            if score == 100
                col = '#00ff00';
            elseif score >= 90
                col = '#ffff00';
            else
                col = '#ff0000';
            end
        end
    end
end
