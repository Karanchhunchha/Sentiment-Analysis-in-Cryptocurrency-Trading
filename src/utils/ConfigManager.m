classdef ConfigManager
    % ConfigManager Reads and manages environment configuration
    
    properties (Constant)
        EnvPath = fullfile(pwd, 'configs', '.env');
    end
    
    methods (Static)
        function env = getEnv()
            % Reads the .env file into a containers.Map
            env = containers.Map('KeyType', 'char', 'ValueType', 'char');
            if ~exist(ConfigManager.EnvPath, 'file')
                examplePath = fullfile(pwd, 'configs', '.env.example');
                if exist(examplePath, 'file')
                    copyfile(examplePath, ConfigManager.EnvPath);
                    warning('No .env found. Auto-created a new one from .env.example at %s. Please configure it.', ConfigManager.EnvPath);
                else
                    warning('Config file not found at %s, and no .env.example exists.', ConfigManager.EnvPath);
                end
                return;
            end
            
            fid = fopen(ConfigManager.EnvPath, 'r');
            while ~feof(fid)
                line = strtrim(fgetl(fid));
                if isempty(line) || startsWith(line, '#') || ~contains(line, '=')
                    continue;
                end
                tokens = split(line, '=');
                if numel(tokens) >= 2
                    key = strtrim(tokens{1});
                    val = strtrim(join(tokens(2:end), '='));
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
