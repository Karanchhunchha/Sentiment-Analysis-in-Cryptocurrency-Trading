%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
classdef test_SentimentEngine < matlab.unittest.TestCase
%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
    % test_SentimentEngine Verifies the NLP classification models to ensure 
    % accurate tracking of bullish/bearish market sentiment.
    
    properties
        Engine
    end
    
    methods(TestMethodSetup)
        function createEngine(testCase)
            % Initialize engine and train Naive Bayes synthetic model
            testCase.Engine = SentimentEngine();
        end
    end
    
    methods(Test)
        function testInitialization(testCase)
            testCase.verifyFalse(isempty(testCase.Engine.MLClassifier));
            testCase.verifyFalse(isempty(testCase.Engine.Vocabulary));
        end
        
        function testBullishSentiment(testCase)
            text = "Bitcoin is pumping hard today, expecting new highs soon!🚀 buy bullish";
            [ml, vader, ratio] = testCase.Engine.analyzeText(text);
            
            % ML Score should lean positive
            testCase.verifyGreaterThan(ml, 0);
            % Lexicon/Vader Score should lean positive
            testCase.verifyGreaterThan(vader, 0);
            % Ratio Score should lean positive
            testCase.verifyGreaterThan(ratio, 0);
        end
        
        function testBearishSentiment(testCase)
            text = "Major crash incoming! Selling all my crypto immediately. bearish drop";
            [ml, vader, ratio] = testCase.Engine.analyzeText(text);
            
            % ML Score should lean negative
            testCase.verifyLessThan(ml, 0);
            % Lexicon/Vader Score should lean negative
            testCase.verifyLessThan(vader, 0);
            % Ratio Score should lean negative
            testCase.verifyLessThan(ratio, 0);
        end
        
        function testNeutralOrEmptySentiment(testCase)
            text = "the and or it is was";
            [~, vader, ratio] = testCase.Engine.analyzeText(text);
            
            % If no sentiment words, ratio and vader should be 0
            testCase.verifyEqual(vader, 0);
            testCase.verifyEqual(ratio, 0);
        end
    end
end
