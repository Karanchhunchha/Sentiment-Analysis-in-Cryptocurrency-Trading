classdef Logger
    % Logger Handles application logging (console + file)
    
    properties (Constant)
        LogDir = fullfile(pwd, 'data', 'logs');
    end
    
    methods (Static)
        function init()
            if ~exist(Logger.LogDir, 'dir')
                mkdir(Logger.LogDir);
            end
        end
        
        function log(level, message, varargin)
            Logger.init();
            
            % Format message
            if ~isempty(varargin)
                msg = sprintf(message, varargin{:});
            else
                msg = message;
            end
            
            timeStr = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            logLine = sprintf('[%s] [%s] %s', timeStr, upper(level), msg);
            
            % Print to console
            disp(logLine);
            
            % Write to file (daily rotating)
            dateStr = datestr(now, 'yyyy-mm-dd');
            logFile = fullfile(Logger.LogDir, sprintf('sentinel_%s.log', dateStr));
            
            fid = fopen(logFile, 'a');
            if fid ~= -1
                fprintf(fid, '%s\n', logLine);
                fclose(fid);
            end
        end
        
        function info(message, varargin)
            Logger.log('INFO', message, varargin{:});
        end
        
        function warn(message, varargin)
            Logger.log('WARN', message, varargin{:});
        end
        
        function warning(message, varargin)
            Logger.log('WARN', message, varargin{:});
        end
        
        function success(message, varargin)
            Logger.log('SUCCESS', message, varargin{:});
        end
        
        function error(message, varargin)
            Logger.log('ERROR', message, varargin{:});
        end
        
        function debug(message, varargin)
            % Check if debug logging is enabled via config
            if strcmp(ConfigManager.getValue('LOG_LEVEL', 'INFO'), 'DEBUG')
                Logger.log('DEBUG', message, varargin{:});
            end
        end
    end
end
