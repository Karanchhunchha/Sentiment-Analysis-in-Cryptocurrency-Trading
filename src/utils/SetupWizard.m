%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef SetupWizard
    % SetupWizard One-click setup for the Research Workstation environment
    
    methods (Static)
        function run()
            Logger.info('Starting Setup Wizard...');
            
            % 1. Create .env if missing
            ConfigManager.getEnv(); % This automatically copies .env.example
            
            % 2. Setup Python Path
            try
                PythonWrapper.setupPath();
                Logger.success('Python Path configured successfully.');
            catch e
                Logger.error('Failed to configure Python Path: %s', e.message);
            end
            
            % 3. Initialize Production Data Folders
            DataFolderInit.run();
            
            % 4. Database Setup (Optional/Mock)
            dbUser = ConfigManager.getValue('DB_USER');
            dbPass = ConfigManager.getValue('DB_PASSWORD');
            if isempty(dbUser) || isempty(dbPass)
                Logger.warn('Database configuration missing in .env. Running in Offline Cache mode.');
            else
                Logger.info('Database credentials found. Connect your database to run schema.sql.');
            end
            
            Logger.info('Setup Complete. The environment is READY.');
        end
    end
end
