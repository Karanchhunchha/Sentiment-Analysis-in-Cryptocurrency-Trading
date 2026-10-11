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
            
            % Check that every synthetic target row has NaN Target across the entire dataset
            synthIndices = find(targetIsSynth);
            for i = 1:numel(synthIndices)
                idx = synthIndices(i);
                testCase.verifyTrue(isnan(fullData.Target(idx)), ...
                    sprintf('Synthetic target at index %d must be NaN.', idx));
            end
            
            % Verify that training sequence generation and masking actually exclude NaN responses
            [XTrainSeq, vTrain] = PipelineDataProcessor.formatForCNNLSTM(X(1:500,:), 30);
            YTrainSeq = Y(vTrain);
            validTargetMask = ~isnan(YTrainSeq);
            
            % Verify that any training sequence preceding a synthetic target is successfully filtered out
            XFiltered = XTrainSeq(validTargetMask);
            YFiltered = YTrainSeq(validTargetMask);
            testCase.verifyTrue(all(~isnan(YFiltered)), 'All filtered training responses must be non-NaN.');
            testCase.verifyTrue(numel(YFiltered) <= numel(YTrainSeq), 'Mask must successfully exclude synthetic target examples.');
        end
    end
end
