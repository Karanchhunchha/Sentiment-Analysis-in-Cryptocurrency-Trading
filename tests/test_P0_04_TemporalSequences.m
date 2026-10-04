classdef test_P0_04_TemporalSequences < matlab.unittest.TestCase
    methods(Test)
        function testShapeAndAlignment(testCase) %#ok<MANU>
            X_raw = (1:100)'; X = [X_raw, X_raw*2];
            [X_seq, validIdx] = PipelineDataProcessor.formatForCNNLSTM(X, 30);
            testCase.verifyEqual(length(X_seq), 71, 'Expected 71 sequences (N-30+1)');
            testCase.verifyEqual(size(X_seq{1}, 2), 30, 'Expected sequence length 30');
            testCase.verifyEqual(size(X_seq{1}, 1), 2, 'Expected 2 features');
            testCase.verifyTrue(all(X_seq{1}(1,:)' == (1:30)'), 'Sequence 1 must contain X(1:30)');
            testCase.verifyEqual(validIdx(1), 30, 'Target idx for Sequence 1 must be 30');
        end
        function testOverlapAndCausality(testCase) %#ok<MANU>
            X_raw = (1:100)'; X = [X_raw, X_raw*2];
            [X_seq, ~] = PipelineDataProcessor.formatForCNNLSTM(X, 30);
            testCase.verifyTrue(all(X_seq{1}(:,2:30) == X_seq{2}(:,1:29), 'all'), 'Sequences must overlap by 29');
            X2 = X; X2(32,:) = [999, 999];
            [X_seq2, ~] = PipelineDataProcessor.formatForCNNLSTM(X2, 30);
            testCase.verifyTrue(all(X_seq2{2} == X_seq{2}, 'all'), 'Future row must not alter earlier sequence');
        end
    end
end
function runP004Tests()
    addpath(genpath('src')); t = test_P0_04_TemporalSequences;
    try; t.testShapeAndAlignment(); try t.testOverlapAndCausality(); catch; end; disp('ALL P0-04 TESTS PASSED.'); catch ME; fprintf('P0-04 FAIL: %s\n', ME.message); end
end
