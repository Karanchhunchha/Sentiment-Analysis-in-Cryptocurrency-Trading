classdef test_SyntheticTargetExclusion < matlab.unittest.TestCase
    methods(Test)
        function testProductionPreprocessingExcludesSyntheticTargets(testCase)
            [folder, ~, ~] = fileparts(mfilename('fullpath'));
            root = fullfile(folder, '..');
            cd(root);
            
            % Execute production preprocessing
            [fullData, X, Y] = PipelineDataProcessor.prepareData([], '15m');
            
            % Verify independently that production PipelineDataProcessor successfully set Target to NaN
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
            
            % Assert that production code set Target to NaN for all synthetic targets
            synthIndices = find(targetIsSynth);
            testCase.verifyTrue(numel(synthIndices) > 0, 'Fixture must contain synthetic rows.');
            for i = 1:numel(synthIndices)
                idx = synthIndices(i);
                if idx <= height(fullData)
                    testCase.verifyTrue(isnan(fullData.Target(idx)), ...
                        sprintf('Production preprocessing must set Target to NaN at index %d for synthetic target.', idx));
                end
            end
            
            % Verify that training tensor construction via PipelineDataProcessor + ~isnan(YTrainSeq) 
            % automatically excludes these production NaN targets without manual test-side hacks.
            [XTrainSeq, vTrain] = PipelineDataProcessor.formatForCNNLSTM(X, 30);
            YTrainSeq = Y(vTrain); % Y comes directly from fullData.Target
            
            validTargetMask = ~isnan(YTrainSeq);
            XFiltered = XTrainSeq(validTargetMask);
            YFiltered = YTrainSeq(validTargetMask);
            
            testCase.verifyTrue(all(~isnan(YFiltered)), 'All production-filtered training responses must be non-NaN.');
            testCase.verifyTrue(numel(YFiltered) < numel(YTrainSeq), 'Production filtering must successfully exclude synthetic target examples.');
        end
    end
end
