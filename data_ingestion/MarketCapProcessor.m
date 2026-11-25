% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto

classdef MarketCapProcessor < handle
    % MARKETCAPPROCESSOR Ingests and cleans external CoinMarketCap CSV data
    
    methods
        function obj = MarketCapProcessor()
        end
        
        function cleanData = processRawCSV(~, inputFilePath)
            disp('================================================');
            disp('   ⚙️ SentinelCrypto CMC Data Processor ⚙️   ');
            disp('================================================');
            
            disp(['📖 Reading raw data from: ' inputFilePath]);
            
            opts = detectImportOptions(inputFilePath, 'Delimiter', ';');
            rawData = readtable(inputFilePath, opts);
            
            cleanData = table();
            cleanData.Datetime = rawData.timeOpen;
            cleanData.Open = rawData.open;
            cleanData.High = rawData.high;
            cleanData.Low = rawData.low;
            cleanData.Close = rawData.close;
            cleanData.Volume = rawData.volume;
            
            % Must process chronologically (past -> future) to avoid lookahead bias
            cleanData = flip(cleanData);
            
            disp(['✅ Successfully processed ' num2str(height(cleanData)) ' records.']);
        end
    end
end
