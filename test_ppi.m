%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
% test_ppi.m
addpath(genpath('src'));

disp('====================================================');
disp('   LIVE MACRO SHOCK TEST: PPI DATA (JULY 15)        ');
disp('====================================================');

macroEngine = MacroEngine();
[liveBias, liveSummary] = macroEngine.fetchLatestMacroBias();
disp('--- LIVE COINTELEGRAPH RSS PULL ---');
disp(['Live Bias: ', num2str(liveBias)]);
disp(['Live Summary: ', liveSummary]);
disp(' ');

disp('--- TESTING MATH: COOLER PPI DATA DROP SCENARIO ---');
% If the live feed doesn't specifically have the letters "PPI" in the top 10 articles yet, 
% we simulate the exact math response when the algorithm sees the PPI drop.

simulatedPPIBias = 0.8; % Extremely bullish macro shock (PPI cooler than expected)
probUp = 0.7; % Technical probability says UP

currentPrice = 64638.50; 
volatility = 45.00; 
bullishOB = 64500.00;

% Strict SL placement
sl = bullishOB - volatility;
risk = currentPrice - sl;

% Default TP (1:2)
default_tp = currentPrice + (risk * 2.0);

macroMultiplier = 1.0;
if (probUp > 0.55 && simulatedPPIBias > 0.3)
    macroMultiplier = 1.5; % The new logic we just injected!
    disp('>>> ALGORITHM TRIGGER: Favorable Macro conditions (Cool PPI) detected!');
    disp('>>> ACTION: Expanding Take Profit targets to capitalize on Short Squeeze.');
end

% New Expanded TPs
tp1 = currentPrice + (risk * 2.0 * macroMultiplier); 
tp2 = currentPrice + (risk * 3.0 * macroMultiplier); 

disp(' ');
disp(sprintf('Entry Price: $%.2f', currentPrice));
disp(sprintf('Stop Loss (SL): $%.2f (Risking %.2f points)', sl, risk));
disp(' ');
disp(sprintf('OLD Algorithm Target (1:2): $%.2f', default_tp));
disp(sprintf('NEW Macro-Adjusted Target (1:3): $%.2f', tp1));
disp(sprintf('NEW Macro-Adjusted Target (1:4.5): $%.2f', tp2));
disp('====================================================');
