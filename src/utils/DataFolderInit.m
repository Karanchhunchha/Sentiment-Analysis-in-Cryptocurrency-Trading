%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef DataFolderInit
    % DataFolderInit Automatically creates the production-grade data folder structure
    
    methods (Static)
        function run()
            Logger.info('Initializing production data folder structure...');
            
            % Define the complete folder tree as specified
            folders = {
                'data/market/ohlcv';
                'data/market/orderbook';
                'data/market/indicators';
                'data/sentiment/twitter';
                'data/sentiment/reddit';
                'data/sentiment/news';
                'data/sentiment/fear_greed';
                'data/macro/fomc';
                'data/macro/cpi';
                'data/macro/rates';
                'data/onchain/glassnode';
                'data/onchain/exchange_flow';
                'data/onchain/whales';
                'data/processed'
            };
            
            for i = 1:length(folders)
                p = fullfile(pwd, folders{i});
                if ~exist(p, 'dir')
                    mkdir(p);
                end
            end
            
            Logger.success('Data folder structure successfully initialized.');
        end
    end
end
