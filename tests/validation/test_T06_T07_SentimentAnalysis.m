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
            absPath = 'D:\Sentiment Analysis in Cryptocurrency Trading\data\sentiment\cryptolin.csv';
            classifier = classifier.train(absPath);
            
            % 2. Verify Classifier returns valid scores
            [nb, svm] = classifier.predict('bitcoin is bullish');
            testCase.verifyTrue(abs(nb) <= 1, 'NB score out of range');
            testCase.verifyTrue(abs(svm) <= 1, 'SVM score out of range');
            
            % 3. Verify metrics
            metrics = classifier.evaluate(absPath);
            testCase.verifyTrue(isfield(metrics.NB, 'Accuracy'), 'NB metrics missing');
            testCase.verifyTrue(isfield(metrics.SVM, 'Accuracy'), 'SVM metrics missing');
        end
    end
end
