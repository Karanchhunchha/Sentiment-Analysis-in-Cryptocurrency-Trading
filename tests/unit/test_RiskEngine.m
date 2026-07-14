classdef test_RiskEngine < matlab.unittest.TestCase
    % test_RiskEngine Validates SL/TP generation and trade rejection logic
    
    properties
        Engine
    end
    
    methods(TestMethodSetup)
        function createEngine(testCase)
            % slMult=1.5, tpMult=3.0, minRR=1.5
            testCase.Engine = RiskEngine(1.5, 3.0, 1.5);
        end
    end
    
    methods(Test)
        function testValidLongTrade(testCase)
            % Current=100, Predicted=110, ATR=2
            % SL Distance = 2 * 1.5 = 3 (SL=97)
            % TP Distance = 2 * 3.0 = 6 (TP=106)
            % Prediction > TP, so actual TP = 106.
            % Risk = 100 - 97 = 3. Reward = 106 - 100 = 6.
            % RR = 6 / 3 = 2.0. >= 1.5. Valid!
            
            [valid, sl, tp] = testCase.Engine.evaluateTrade(100, 110, 2);
            
            testCase.verifyTrue(valid);
            testCase.verifyEqual(sl, 97);
            testCase.verifyEqual(tp, 106);
        end
        
        function testInvalidLongTrade(testCase)
            % Current=100, Predicted=102, ATR=2
            % SL Distance = 3 (SL=97)
            % TP Distance = 6 (TP=106)
            % Prediction < TP, so actual TP gets clamped to 102.
            % Risk = 3. Reward = 102 - 100 = 2.
            % RR = 2 / 3 = 0.66. NOT >= 1.5. Invalid!
            
            [valid, ~, ~] = testCase.Engine.evaluateTrade(100, 102, 2);
            
            testCase.verifyFalse(valid, 'Trade with R:R < 1.5 should be rejected');
        end
        
        function testValidShortTrade(testCase)
            % Current=100, Predicted=90, ATR=2
            % SL Distance = 3 (SL=103)
            % TP Distance = 6 (TP=94)
            % Prediction < TP, so actual TP = 94.
            % Risk = 103 - 100 = 3. Reward = 100 - 94 = 6.
            % RR = 2.0. Valid!
            
            [valid, sl, tp] = testCase.Engine.evaluateTrade(100, 90, 2);
            
            testCase.verifyTrue(valid);
            testCase.verifyEqual(sl, 103);
            testCase.verifyEqual(tp, 94);
        end
    end
end
