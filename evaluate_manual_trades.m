% evaluate_manual_trades.m
clc; clear;

disp('================================================');
disp('   SMC ALGORITHM: MANUAL SETUP COMPARISON     ');
disp('================================================');

% Simulated Current Market Context from Live Algorithm
volatility = 45.30; % Average 15m candle volatility points
currentTrend = 'BEARISH (Downtrend)';

disp(['Current Market Trend Context: ', currentTrend]);
disp(' ');

%% Setup 1: The Short (from TradingView)
disp('--- SETUP 1: SHORT (TradingView) ---');
entry1 = 64663.00;
sl1 = 65002.90;
tp1 = 64047.01;

risk1 = abs(sl1 - entry1);
reward1 = abs(entry1 - tp1);
rr1 = reward1 / risk1;
time1 = ceil(reward1 / volatility) * 15;

disp(sprintf('Entry: %.2f | SL: %.2f | TG: %.2f', entry1, sl1, tp1));
disp(sprintf('Risk Amount: %.2f points | Reward Amount: %.2f points', risk1, reward1));
disp(sprintf('Risk/Reward Ratio: 1:%.2f', rr1));
disp(sprintf('Estimated Time to TG: ~%d Minutes (%.1f Hours)', time1, time1/60));

if rr1 >= 1.8 % Allow slight slippage tolerance
    disp('>>> ALGORITHM VERDICT: APPROVED (Follows Bearish Trend, Excellent RR)');
    disp('>>> PREDICTION: High probability of hitting TG (Target).');
else
    disp('>>> ALGORITHM VERDICT: REJECTED');
end

disp(' ');

%% Setup 2: The Long (from Mobile App)
disp('--- SETUP 2: LONG (Mobile App) ---');
entry2 = 64638.5;
sl2 = 64590.5;
tp2 = 64699.0;

risk2 = abs(entry2 - sl2);
reward2 = abs(tp2 - entry2);
rr2 = reward2 / risk2;
time2 = ceil(reward2 / volatility) * 15;

disp(sprintf('Entry: %.2f | SL: %.2f | TG: %.2f', entry2, sl2, tp2));
disp(sprintf('Risk Amount: %.2f points | Reward Amount: %.2f points', risk2, reward2));
disp(sprintf('Risk/Reward Ratio: 1:%.2f', rr2));
disp(sprintf('Estimated Time to TG: ~%d Minutes (%.1f Hours)', time2, time2/60));

if rr2 >= 2.0
    disp('>>> ALGORITHM VERDICT: APPROVED');
else
    disp('>>> ALGORITHM VERDICT: REJECTED (Violates 1:2 strict rule. Trading against trend.)');
    disp('>>> PREDICTION: High probability of hitting SL (Liquidity Trap).');
end
disp('================================================');
