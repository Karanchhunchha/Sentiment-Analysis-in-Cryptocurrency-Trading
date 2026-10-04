classdef test_FallbackResilience < matlab.unittest.TestCase
    methods (Test)
        function testLiveFailureFallback(testCase)
             % API failure should trigger CSV fallback
             loader = PriceDataLoader('INVALID_SYMBOL_FOR_API', '1h');
             data = loader.fetchRecentHistory(20);
             testCase.assertFalse(isempty(data), 'CSV fallback failed to provide data on API failure.');
        end

        function testCSVContainsRealData(testCase)
             loader = PriceDataLoader('BTCUSDT', '1h');
             data = loader.loadHistoricalCSV('D:\Sentiment Analysis in Cryptocurrency Trading\data\market\btc.csv');
             testCase.assertTrue(height(data) > 0, 'CSV fallback data is empty.');
             testCase.assertTrue(iscolumn(data.Close), 'Missing Close column in data.');
        end

        function testInvalidCSVFailure(testCase)
             loader = PriceDataLoader('BTCUSDT', '1h');
             testCase.assertError(@() loader.loadHistoricalCSV('non_existent_file.csv'), 'PriceDataLoader:FileNotFound');
        end
    end
end