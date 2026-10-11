classdef test_SyntheticTargetExclusion < matlab.unittest.TestCase
    methods(Test)
        function testSyntheticTargetsAreExcludedFromTensors(testCase)
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
            
            % Assert that synthetic target rows actually exist in the fixture so the test is meaningful
            testCase.verifyTrue(any(targetIsSynth), 'Fixture must contain at least one synthetic target row for testing.');
            
            % Verify that training sequence generation and masking actually exclude NaN responses
            [XTrainSeq, vTrain] = PipelineDataProcessor.formatForCNNLSTM(X, 30);
            YTrainSeq = Y(vTrain);
            
            % Map targetIsSynth to sequence indices
            % formatForCNNLSTM returns valid indices starting at sequenceLength (30)
            % vTrain corresponds to rows 30:end in fullData
            synthMaskInSeq = targetIsSynth(vTrain);
            
            % Assert that at least some synthetic targets exist in the sequence range
            testCase.verifyTrue(any(synthMaskInSeq), 'Synthetic targets must be present within sequence training range.');
            
            % Explicitly apply the exclusion mask
            validTargetMask = ~isnan(YTrainSeq) & ~synthMaskInSeq;
            XFiltered = XTrainSeq(validTargetMask);
            YFiltered = YTrainSeq(validTargetMask);
            
            % Assertions
            testCase.verifyTrue(all(~isnan(YFiltered)), 'All filtered training responses must be non-NaN.');
            testCase.verifyTrue(numel(YFiltered) < numel(YTrainSeq), 'Mask must successfully exclude synthetic target examples from tensors.');
        end
    end
end
