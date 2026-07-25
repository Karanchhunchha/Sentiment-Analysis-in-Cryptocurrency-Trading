%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef ConfigManager
    % ConfigManager Reads and manages environment configuration
    
    methods (Static)
        function path = getEnvPath()
            persistent resolvedPath;
            if isempty(resolvedPath)
                [utilsDir, ~, ~] = fileparts(which('ConfigManager'));
                if isempty(utilsDir)
                    % Fallback to pwd if not on path
                    resolvedPath = fullfile(pwd, 'configs', '.env');
                else
                    [srcDir, ~, ~] = fileparts(utilsDir);
                    [rootDir, ~, ~] = fileparts(srcDir);
                    resolvedPath = fullfile(rootDir, 'configs', '.env');
                end
            end
            path = resolvedPath;
        end
        
        function env = getEnv()
            % Reads the .env file into a containers.Map
            env = containers.Map('KeyType', 'char', 'ValueType', 'char');
            envPath = ConfigManager.getEnvPath();
            if ~exist(envPath, 'file')
                warning('Config file not found at %s.', envPath);
                return;
            end
            
            fid = fopen(envPath, 'r');
            while ~feof(fid)
                line = strtrim(fgetl(fid));
                if isempty(line) || startsWith(line, '#') || ~contains(line, '=')
                    continue;
                end
                tokens = split(line, '=');
                if numel(tokens) >= 2
                    key = char(strtrim(tokens{1}));
                    val = char(strtrim(join(tokens(2:end), '=')));
                    env(key) = val;
                end
            end
            fclose(fid);
        end
        
        function val = getValue(key, defaultVal)
            if nargin < 2
                defaultVal = '';
            end
            env = ConfigManager.getEnv();
            if isKey(env, key)
                val = env(key);
            else
                val = defaultVal;
            end
        end
    end
end
