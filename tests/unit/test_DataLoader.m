%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef test_DataLoader < matlab.unittest.TestCase
    % test_DataLoader Verifies data ingestion and formatting
    
    methods(Test)
        function testLoadHistorical(testCase)
            loader = PriceDataLoader('BTCUSDT', '1h');
            
            % Generate a temporary CSV to load
            tempData = table(datetime('today'), 100, 110, 90, 105, 1000, ...
                'VariableNames', {'Date', 'Open', 'High', 'Low', 'Close', 'Volume'});
            tempFile = fullfile(tempdir, 'temp_test.csv');
            writetable(tempData, tempFile);
            
            data = loader.loadHistoricalCSV(tempFile);
            
            testCase.verifyEqual(height(data), 1);
            testCase.verifyEqual(data.Close(1), 105);
            
            % Cleanup
            delete(tempFile);
        end
        
        function testMissingFileThrowsError(testCase)
            loader = PriceDataLoader('BTCUSDT', '1h');
            
            testCase.verifyError(@() loader.loadHistoricalCSV('nonexistent_file.csv'), 'PriceDataLoader:FileNotFound');
        end
    end
end
