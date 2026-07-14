% Author: Karan Chhunchha (karanchhunchha@gmail.com)
% MathWorks Challenge #239 - SentinelCrypto
% test_sentiment.m

clc; clear;
addpath('sentiment_analysis');

fusion = SentimentFusion();

disp('----------------------------------------------------');
disp('   🧪 Testing SentinelCrypto Sentiment Fusion 🧪   ');
disp('----------------------------------------------------');

sampleText = "Bitcoin is seeing a massive bullish surge today! I'm buying more before it goes to the moon.";
disp(['Sample Text: "' char(sampleText) '"']);

[fusedScore, scores] = fusion.evaluate(sampleText);

disp(' ');
disp('--- Individual Scores ---');
disp(['VADER Score:      ' num2str(scores.Vader)]);
disp(['Ratio-Rule Score: ' num2str(scores.RatioRule)]);
disp(['FinBERT Score:    ' num2str(scores.Finbert)]);
disp(['FinBERT Conf:     ' num2str(scores.Confidence)]);
disp('-------------------------');
disp(['🚀 FUSED SCORE:   ' num2str(fusedScore)]);
disp('----------------------------------------------------');
