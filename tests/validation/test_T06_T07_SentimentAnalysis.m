classdef test_T06_T07_SentimentAnalysis < matlab.unittest.TestCase
    properties
        Engine
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            testCase.Engine = SentimentEngine();
        end
    end
    
    methods (Test)
        function testClassifierPerformance(testCase)
            % 1. Load CryptoLin
            classifier = SentimentClassifier();
            % classifier = classifier.train('data/sentiment/cryptolin.csv');
            % Resolve project root from this test file's location (2 dirs up from tests/validation/)
            thisDir = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(fileparts(thisDir));
            absPath = fullfile(projectRoot, 'data', 'sentiment', 'cryptolin.csv');
            if ~isfile(absPath)
                testCase.assumeFail(sprintf('cryptolin.csv not found at: %s — dataset missing, test skipped.', absPath));
            end
            classifier = classifier.train(absPath);
            
            % 2. Verify Classifier returns valid scores
            [nb, svm] = classifier.predict('bitcoin is bullish');
            testCase.verifyTrue(abs(nb) <= 1, 'NB score out of range');
            testCase.verifyTrue(abs(svm) <= 1, 'SVM score out of range');
            
            % 3. Verify metrics — use same absPath computed above
            metrics = classifier.evaluate(absPath);
            testCase.verifyTrue(isfield(metrics.NB, 'Accuracy'), 'NB metrics missing');
            testCase.verifyTrue(isfield(metrics.SVM, 'Accuracy'), 'SVM metrics missing');
        end
    end
end
