%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef PythonWrapper
    % PythonWrapper Safely bridges MATLAB and Python, handling syntax variations
    
    methods (Static)
        function setupPath(modulePath)
            % Ensure python is loaded
            pe = pyenv;
            if isempty(pe.Version)
                error('Python environment not found in MATLAB.');
            end
            
            % Resolve absolute path
            if nargin < 1
                modulePath = fullfile(pwd, 'python_modules');
            end
            
            absPath = char(java.io.File(modulePath).getAbsolutePath());
            
            % Safely add to py.sys.path
            pathList = py.sys.path;
            
            % Check if it exists
            exists = false;
            if isa(pathList, 'py.list')
                % Older MATLAB syntax or standard list
                if count(pathList, absPath) > 0
                    exists = true;
                end
            else
                % Fallback checking logic for newer MATLAB PyList representations
                listCell = cell(pathList);
                for i = 1:length(listCell)
                    if strcmp(char(listCell{i}), absPath)
                        exists = true;
                        break;
                    end
                end
            end
            
            if ~exists
                try
                    % Attempt standard py.list.insert (MATLAB recommended)
                    insert(pathList, int32(0), absPath);
                catch
                    try
                        % Fallback to direct Python method call if exposed
                        pathList.append(absPath);
                    catch e
                        Logger.error('Failed to inject Python path: %s', e.message);
                    end
                end
            end
            Logger.debug('Python path configured for: %s', absPath);
        end
    end
end
