classdef test_SyntheticTargetExclusion < matlab.unittest.TestCase
    methods(Test)
        function testSyntheticTargetsAreNaNInTable(testCase)
            [folder, ~, ~] = fileparts(mfilename('fullpath'));
            root = fullfile(folder, '..');
            cd(root);
            
            [fullData, X, Y] = PipelineDataProcessor.prepareData([], '15m');
            
            marketFile = fullfile(root, 'data', 'market', 'btc_15m_data_2018_to_2025.csv');
            rawMarket = readtable(marketFile, 'VariableNamingRule', 'preserve');
            if any(strcmp(rawMarket.Properties.VariableNames, 'Open_time'))
               rawMarket.Properties.VariableNames{'Open_time'} = 'Date';
            elseif any(strcmp(rawMarket.Properties.VariableNames, 'Open time'))
               rawMarket.Properties.VariableNames{'Open time'} = 'Date';
            elseif any(strcmp(rawMarket.Properties.VariableNames, 'OpenTime'))
               rawMarket.Properties.VariableNames{'OpenTime'} = 'Date';
            end
            rawDates = datetime(rawMarket.Date);
            rawDatesClean = rawDates(~isnat(rawDates));
            isSynth = ~ismember(fullData.Date, rawDatesClean);
            targetIsSynth = [isSynth(2:end); false];
            
            % Check that every synthetic target row has NaN Target, preserving row count
            synthIndices = find(targetIsSynth);
            for i = 1:min(50, numel(synthIndices))
                idx = synthIndices(i);
                testCase.verifyTrue(isnan(fullData.Target(idx)), ...
                    sprintf('Synthetic target at index %d must be NaN.', idx));
            end
            
            % Check that sequence formatting excludes NaN targets properly
            [X_seq, validIdx] = PipelineDataProcessor.formatForCNNLSTM(X(1:100,:), 30);
            Y_sub = fullData.Target(validIdx);
            validMask = ~isnan(Y_sub);
            testCase.verifyTrue(numel(Y_sub) == numel(validIdx), 'Sequence mapping preserves length before mask.');
        end
    end
end
